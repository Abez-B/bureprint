---
name: document-processing
description: Guides local-first document handling, PDF and image import, preview rendering, print settings transformations, format validation, rasterization boundaries, and temporary file management in BurePrint. Activate when working on file pickers, PDF parsing, raster converters, or print options.
---

# Skill: Document Processing

## Purpose
Governs the safe, private, local-first handling of user documents (PDFs, images), print settings configuration, rasterization pipelines, and temporary storage cleanup.

---

## Architecture Boundaries

1. **Local-First Processing**:
   - Zero telemetry, zero cloud rendering. All conversions and validations happen entirely on the local device.
2. **Separation of Conversion and Transport**:
   - The document engine takes input files and outputs requested MIME streams (e.g. `application/pdf`, `image/pwg-raster`).
   - The document engine MUST NOT talk to network sockets or USB endpoints directly.
3. **Print Settings Model**:
   - Centralize print options: page range, copy count, orientation (portrait/landscape), paper size (A4, Letter, 4x6, etc.), duplex modes, color/monochrome, and scaling/fit.
   - Constrain selectable options based on the target printer's advertised capabilities.

---

## Safety, Performance, and Memory Guardrails

1. **Oversized and Malformed Files**:
   - Enforce hard size boundaries before loading file bytes into RAM.
   - For PDFs and high-resolution images, stream pages on demand rather than decoding all pages into memory simultaneously to avoid Android OOM (Out Of Memory) crashes.
   - Validate magic bytes (`%PDF-` for PDFs, standard headers for PNG/JPEG) before attempting full parsing.
2. **Temporary File Management**:
   - Store scratch files strictly in the application cache directory (`cacheDir`).
   - Use deterministic cleanup in `finally` blocks or via a dedicated `TemporaryFileManager`.
   - Purge old or orphaned scratch files on app startup.

---

## Step-by-Step Document Flow

1. **Import & Validation**:
   - User selects file via system file picker.
   - Verify file accessibility, length, and format header.
2. **Page Count & Preview**:
   - Extract page count and dimensions.
   - Generate low-resolution page thumbnails for the UI preview carousel.
3. **Settings Application**:
   - Filter pages based on specified page ranges (e.g., `1-3, 5`).
   - Apply rotation, fit-to-page scaling, and color mode flags.
4. **Target Format Conversion**:
   - If printer accepts PDF directly: prepare clean PDF byte stream.
   - If printer requires raster format: render page bitmaps and encode into PWG Raster or PCLm.
5. **Post-Print Cleanup**:
   - Immediately delete generated intermediate raster buffers and temporary files.

---

## Validation & Testing

- Unit tests for page range parsing (e.g., invalid strings like `5-2`, `abc`, overlapping numbers).
- Tests for file cleanup execution on error/cancel.
- Memory leak and OOM regression checks with multi-page sample documents.
