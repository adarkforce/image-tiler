#include <algorithm>
#include <atomic>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <future>
#include <iostream>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>
#include <vector>
#include <vips/vips8>
#include <zlib.h>

namespace fs = std::filesystem;
using namespace vips;

struct Config {
  std::string inputs_file;
  std::string outputs_file;
  int tile_size = 512;
  std::string suffix = ".jpg";
  int jpeg_quality = 85;
  unsigned int threads = 0;
  bool keep_tiles = false;
};

struct ImageTask {
  std::string input_path;
  std::string output_path;
  size_t index;
};

struct ProcessResult {
  size_t index;
  bool success;
  std::string error_message;
  int width;
  int height;
};

struct TileInfo {
  std::string key;
  std::string binary_name;
  size_t start_offset;
  size_t size;
};

std::mutex cout_mutex;
std::atomic<size_t> completed_count{0};

void print_usage(const char *program_name) {
  std::cerr << "Usage: " << program_name << " [OPTIONS]\n\n"
            << "Generate Google DeepZoom tiles from images using libvips.\n\n"
            << "Required arguments:\n"
            << "  --inputs <file>        Input file with image paths (one per "
               "line)\n"
            << "  --outputs <file>       Output file with tile folder paths "
               "(one per line)\n\n"
            << "Optional arguments:\n"
            << "  --tile-size <int>      Tile size (default: 512)\n"
            << "  --suffix <ext>         Tile format: .png, .jpg, .jpeg "
               "(default: .jpg)\n"
            << "  --jpeg-quality <int>   JPEG quality 1-100 (default: 85)\n"
            << "  --threads <int>        Number of parallel workers (default: "
               "hardware concurrency)\n"
            << "  --keep-tiles           Keep original tile files after "
               "merging (default: false)\n"
            << "  --help                 Show this help message\n";
}

Config parse_args(int argc, char *argv[]) {
  Config config;

  for (int i = 1; i < argc; ++i) {
    std::string arg = argv[i];

    if (arg == "--help" || arg == "-h") {
      print_usage(argv[0]);
      exit(0);
    } else if (arg == "--inputs") {
      if (i + 1 < argc) {
        config.inputs_file = argv[++i];
      } else {
        throw std::runtime_error("--inputs requires a value");
      }
    } else if (arg == "--outputs") {
      if (i + 1 < argc) {
        config.outputs_file = argv[++i];
      } else {
        throw std::runtime_error("--outputs requires a value");
      }
    } else if (arg == "--tile-size") {
      if (i + 1 < argc) {
        config.tile_size = std::stoi(argv[++i]);
        if (config.tile_size <= 0) {
          throw std::runtime_error("tile-size must be positive");
        }
      } else {
        throw std::runtime_error("--tile-size requires a value");
      }
    } else if (arg == "--suffix") {
      if (i + 1 < argc) {
        config.suffix = argv[++i];
        if (config.suffix != ".png" && config.suffix != ".jpg" &&
            config.suffix != ".jpeg") {
          throw std::runtime_error("suffix must be .png, .jpg, or .jpeg");
        }
      } else {
        throw std::runtime_error("--suffix requires a value");
      }
    } else if (arg == "--jpeg-quality") {
      if (i + 1 < argc) {
        config.jpeg_quality = std::stoi(argv[++i]);
        if (config.jpeg_quality < 1 || config.jpeg_quality > 100) {
          throw std::runtime_error("jpeg-quality must be between 1 and 100");
        }
      } else {
        throw std::runtime_error("--jpeg-quality requires a value");
      }
    } else if (arg == "--threads") {
      if (i + 1 < argc) {
        config.threads = std::stoi(argv[++i]);
      } else {
        throw std::runtime_error("--threads requires a value");
      }
    } else if (arg == "--keep-tiles") {
      config.keep_tiles = true;
    } else {
      throw std::runtime_error("Unknown argument: " + arg);
    }
  }

  if (config.inputs_file.empty()) {
    throw std::runtime_error("--inputs is required");
  }
  if (config.outputs_file.empty()) {
    throw std::runtime_error("--outputs is required");
  }

  if (config.threads == 0) {
    config.threads = std::thread::hardware_concurrency();
    if (config.threads == 0)
      config.threads = 4;
  }

  return config;
}

std::vector<ImageTask> read_tasks(const std::string &input_file,
                                  const std::string &output_file) {
  std::vector<ImageTask> tasks;
  std::ifstream inputs(input_file);
  std::ifstream outputs(output_file);

  if (!inputs.is_open()) {
    throw std::runtime_error("Cannot open input file: " + input_file);
  }
  if (!outputs.is_open()) {
    throw std::runtime_error("Cannot open output file: " + output_file);
  }

  std::string input_path, output_path;
  size_t index = 0;
  while (std::getline(inputs, input_path) &&
         std::getline(outputs, output_path)) {
    if (!input_path.empty() && !output_path.empty()) {
      tasks.push_back({input_path, output_path, index++});
    }
  }

  return tasks;
}

int next_power_of_2(int n) {
  if (n <= 0)
    return 1;
  int power = 1;
  while (power < n) {
    power *= 2;
  }
  return power;
}

std::vector<char> gzip_compress(const std::vector<char> &data) {
  z_stream stream;
  stream.zalloc = Z_NULL;
  stream.zfree = Z_NULL;
  stream.opaque = Z_NULL;

  if (deflateInit2(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15 + 16, 8,
                   Z_DEFAULT_STRATEGY) != Z_OK) {
    throw std::runtime_error("Failed to initialize gzip compression");
  }

  std::vector<char> compressed;
  compressed.resize(deflateBound(&stream, data.size()));

  stream.avail_in = data.size();
  stream.next_in = reinterpret_cast<Bytef *>(const_cast<char *>(data.data()));
  stream.avail_out = compressed.size();
  stream.next_out = reinterpret_cast<Bytef *>(compressed.data());

  if (deflate(&stream, Z_FINISH) != Z_STREAM_END) {
    deflateEnd(&stream);
    throw std::runtime_error("Failed to compress data");
  }

  compressed.resize(stream.total_out);
  deflateEnd(&stream);

  return compressed;
}

std::vector<TileInfo> merge_tiles_to_binary(const fs::path &tile_folder,
                                            const std::string &binary_name,
                                            bool keep_tiles) {
  std::vector<TileInfo> tiles_map;
  fs::path binary_path = tile_folder / binary_name;
  std::ofstream binary_file(binary_path, std::ios::binary);

  if (!binary_file) {
    throw std::runtime_error("Cannot create binary file: " +
                             binary_path.string());
  }

  size_t current_offset = 0;

  // Collect all tile files
  std::vector<fs::path> tile_files;
  for (const auto &level_entry : fs::directory_iterator(tile_folder)) {
    if (!level_entry.is_directory())
      continue;
    std::string level_name = level_entry.path().filename().string();
    if (!std::all_of(level_name.begin(), level_name.end(), ::isdigit))
      continue;

    for (const auto &y_entry : fs::directory_iterator(level_entry)) {
      if (!y_entry.is_directory())
        continue;

      for (const auto &tile_entry : fs::directory_iterator(y_entry)) {
        if (!tile_entry.is_regular_file())
          continue;
        std::string ext = tile_entry.path().extension().string();
        std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);
        if (ext == ".png" || ext == ".jpg" || ext == ".jpeg") {
          tile_files.push_back(tile_entry.path());
        }
      }
    }
  }

  // Sort tiles for consistent ordering
  std::sort(tile_files.begin(), tile_files.end());

  // Process each tile
  for (const auto &tile_path : tile_files) {
    // Read tile data
    std::ifstream tile_file(tile_path, std::ios::binary);
    std::vector<char> tile_data((std::istreambuf_iterator<char>(tile_file)),
                                std::istreambuf_iterator<char>());
    tile_file.close();

    // Compress tile
    std::vector<char> compressed = gzip_compress(tile_data);

    // Write to binary file
    binary_file.write(compressed.data(), compressed.size());

    // Extract level, y, x from path
    fs::path parent = tile_path.parent_path();
    std::string tile_x = tile_path.stem().string();
    std::string tile_y = parent.filename().string();
    std::string level = parent.parent_path().filename().string();

    std::string key = level + "_" + tile_y + "_" + tile_x;

    tiles_map.push_back({key, binary_name, current_offset, compressed.size()});

    current_offset += compressed.size();
  }

  binary_file.close();

  // Delete tile directories if not keeping
  if (!keep_tiles) {
    for (const auto &entry : fs::directory_iterator(tile_folder)) {
      if (!entry.is_directory())
        continue;
      std::string name = entry.path().filename().string();
      if (std::all_of(name.begin(), name.end(), ::isdigit)) {
        fs::remove_all(entry.path());
      }
    }

    // Remove blank.png if exists
    fs::path blank_png = tile_folder / "blank.png";
    if (fs::exists(blank_png)) {
      fs::remove(blank_png);
    }
  }

  return tiles_map;
}

void write_metadata(const fs::path &output_folder, int width, int height,
                    int tile_size, const std::vector<TileInfo> &tiles_map) {
  fs::path meta_path = output_folder / "metadata.json";
  std::ofstream meta_file(meta_path);

  if (!meta_file) {
    throw std::runtime_error("Cannot create metadata file: " +
                             meta_path.string());
  }

  meta_file << "{\n";
  meta_file << "  \"width\": " << width << ",\n";
  meta_file << "  \"height\": " << height << ",\n";
  meta_file << "  \"tile_size\": " << tile_size << ",\n";
  meta_file << "  \"tiles\": {\n";

  for (size_t i = 0; i < tiles_map.size(); ++i) {
    const auto &tile = tiles_map[i];
    meta_file << "    \"" << tile.key << "\": {\n";
    meta_file << "      \"binaryName\": \"" << tile.binary_name << "\",\n";
    meta_file << "      \"startOffset\": " << tile.start_offset << ",\n";
    meta_file << "      \"size\": " << tile.size << "\n";
    meta_file << "    }";
    if (i < tiles_map.size() - 1) {
      meta_file << ",";
    }
    meta_file << "\n";
  }

  meta_file << "  }\n";
  meta_file << "}\n";

  meta_file.close();
}

ProcessResult process_image(const ImageTask &task, const Config &config,
                            size_t total) {
  ProcessResult result{task.index, false, "", 0, 0};

  try {
    VImage image = VImage::new_from_file(task.input_path.c_str());

    // Get original dimensions
    int width = image.width();
    int height = image.height();

    // Calculate target size (next power of 2, square)
    int max_dim = std::max(width, height);
    int target_size = next_power_of_2(max_dim);

    {
      std::lock_guard<std::mutex> lock(cout_mutex);
      std::cout << "[" << task.index + 1 << "] " << task.input_path << ": "
                << width << "x" << height << " -> " << target_size << "x"
                << target_size << std::endl;
    }

    // Resize image to square target size
    image =
        image.resize(static_cast<double>(target_size) / width,
                     VImage::option()->set(
                         "vscale", static_cast<double>(target_size) / height));

    auto options = VImage::option()
                       ->set("layout", VIPS_FOREIGN_DZ_LAYOUT_GOOGLE)
                       ->set("depth", VIPS_FOREIGN_DZ_DEPTH_ONETILE)
                       ->set("tile_size", config.tile_size)
                       ->set("skip_blanks", -1)
                       ->set("suffix", config.suffix.c_str());

    // Set JPEG quality if using JPEG format
    if (config.suffix == ".jpg" || config.suffix == ".jpeg") {
      options->set("Q", config.jpeg_quality);
    }

    image.dzsave(task.output_path.c_str(), options);

    result.success = true;
    result.width = target_size;
    result.height = target_size;

    // Merge tiles to binary
    {
      std::lock_guard<std::mutex> lock(cout_mutex);
      std::cout << "  Merging tiles to binary..." << std::endl;
    }

    auto tiles_map = merge_tiles_to_binary(fs::path(task.output_path),
                                           "tiles_000.binz", config.keep_tiles);

    // Write metadata
    write_metadata(fs::path(task.output_path), target_size, target_size,
                   config.tile_size, tiles_map);

    size_t current = ++completed_count;
    {
      std::lock_guard<std::mutex> lock(cout_mutex);
      std::cout << "[" << current << "/" << total << "] ✓ " << task.input_path
                << " -> " << task.output_path << " (" << tiles_map.size()
                << " tiles)" << std::endl;
    }

  } catch (const std::exception &e) {
    result.error_message = e.what();
    {
      std::lock_guard<std::mutex> lock(cout_mutex);
      std::cerr << "[ERROR] " << task.input_path << ": " << e.what()
                << std::endl;
    }
  }

  return result;
}

int main(int argc, char *argv[]) {
  if (VIPS_INIT(argv[0])) {
    vips_error_exit(nullptr);
  }

  try {
    Config config = parse_args(argc, argv);

    auto tasks = read_tasks(config.inputs_file, config.outputs_file);

    if (tasks.empty()) {
      std::cout << "No tasks to process." << std::endl;
      vips_shutdown();
      return 0;
    }

    std::cout << "Configuration:\n"
              << "  Tile size: " << config.tile_size << "\n"
              << "  Format: " << config.suffix << "\n"
              << "  JPEG quality: " << config.jpeg_quality << "\n"
              << "  Threads: " << config.threads << "\n"
              << "  Keep tiles: " << (config.keep_tiles ? "yes" : "no") << "\n"
              << "\nProcessing " << tasks.size() << " images...\n"
              << std::endl;

    // Process images in parallel using thread pool pattern
    std::vector<std::future<ProcessResult>> futures;
    futures.reserve(tasks.size());

    for (const auto &task : tasks) {
      futures.push_back(std::async(std::launch::async, process_image, task,
                                   std::ref(config), tasks.size()));

      // Limit concurrent tasks to avoid overwhelming the system
      if (futures.size() >= config.threads) {
        futures.front().wait();
        futures.erase(futures.begin());
      }
    }

    // Wait for remaining tasks
    for (auto &future : futures) {
      future.wait();
    }

    std::cout << "\nCompleted: " << completed_count.load() << "/"
              << tasks.size() << " images" << std::endl;

    if (completed_count.load() < tasks.size()) {
      std::cerr << "Warning: " << (tasks.size() - completed_count.load())
                << " images failed to process" << std::endl;
      vips_shutdown();
      return 1;
    }

    std::cout << "All images processed successfully!" << std::endl;

  } catch (const std::exception &e) {
    std::cerr << "Error: " << e.what() << std::endl;
    print_usage(argv[0]);
    vips_shutdown();
    return 1;
  }

  vips_shutdown();
  return 0;
}
