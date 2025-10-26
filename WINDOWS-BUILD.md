# Building for Windows from macOS

## Recommended Method: Docker (Easiest)

This method builds a fully portable Windows executable with all dependencies included.

### Steps:

1. **Build the Windows package:**

   ```bash
   ./build-windows-docker.sh
   ```

2. **Upload to GitHub:**

   - Go to your GitHub repository
   - Create a new Release
   - Upload the generated `MyProject-Windows-Portable-YYYYMMDD.zip` file
   - Publish the release

3. **On Windows machine (with GitHub access):**
   - Download the ZIP from your GitHub release
   - Extract it to any folder
   - Run `MyProject.exe` from Command Prompt:
     ```cmd
     MyProject.exe inputs.txt outputs.txt 256
     ```

## What's Included

The portable package includes:

- `MyProject.exe` - The main executable
- All required DLLs (libvips, glib, etc.)
- `README.md` - Usage instructions
- `download_test_images.sh` - Test script (requires bash/WSL on Windows)

## Creating Test Files on Windows

Create `inputs.txt`:

```text
C:\path\to\image1.jpg
C:\path\to\image2.png
```

Create `outputs.txt`:

```text
C:\path\to\output1
C:\path\to\output2
```

Then run:

```cmd
MyProject.exe inputs.txt outputs.txt 256
```

## Troubleshooting

### Missing DLL errors

If you get DLL errors, the package may be incomplete. Rebuild with:

```bash
./build-windows-docker.sh
```

### Permission errors on Windows

Run Command Prompt as Administrator.

### Path issues

Use absolute paths in inputs.txt and outputs.txt on Windows.

## Alternative: Manual Cross-Compilation

If Docker doesn't work, you can try manual cross-compilation:

```bash
./build-windows.sh
```

This requires downloading pre-built vips binaries manually from:
https://github.com/libvips/build-win64-mxe/releases

## File Transfer via GitHub

Since your Windows machine only has GitHub access:

1. **Create a private repository** (if needed for security)
2. **Use GitHub Releases** to transfer the ZIP file
3. **Or commit the ZIP** to a branch (not recommended for large files)
4. **Use Git LFS** for large files (if available)

Example workflow:

```bash
# After building
git checkout -b windows-build
git add MyProject-Windows-Portable-*.zip
git commit -m "Add Windows build"
git push origin windows-build
```

Then on Windows:

```cmd
git clone https://github.com/yourusername/yourrepo.git
cd yourrepo
git checkout windows-build
```
