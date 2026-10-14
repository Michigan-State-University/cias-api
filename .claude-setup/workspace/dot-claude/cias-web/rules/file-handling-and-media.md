# File Handling & Media

## File Upload — FileUpload Component

**Location**: `app/components/FileUpload/index.tsx`

Built on `react-dropzone` with support for single and multiple file uploads.

### Props (discriminated union)

```typescript
// Single file mode
<FileUpload
  value={file}                    // Nullable<AppFile>
  onUpload={(file: File) => {}}
  onRemoveFile={() => {}}
  acceptedFormats=".pdf,.docx"
  maxSize={5242880}               // bytes (default: MAX_FILE_SIZE = 5MB)
  label="Upload document"
  disabled={false}
  loading={false}
  error="File too large"
/>

// Multiple files mode
<FileUpload
  multiple
  value={files}                   // AppFile[]
  onUpload={(files: File[]) => {}}
  onRemoveFile={(id: string) => {}}
  acceptedFormats={['.png', '.jpg']}
/>
```

### Size constraints

```typescript
// app/global/constants/file.ts
export const MAX_FILE_SIZE = 5242880;   // 5 MB
export const BYTES_IN_MB = 1000000;
```

The `maxSizeMap` prop allows per-format size limits:

```typescript
maxSizeMap={new Map([
  ['.mp4', 50 * BYTES_IN_MB],
  ['.pdf', 10 * BYTES_IN_MB],
])}
```

### Animation

Uses Framer Motion for error/success state transitions (`<AnimatePresence>` with `<motion.div>`).

---

## File Download

**Location**: `app/utils/fileDownloader/`

Factory pattern with multiple implementations:

| Class | Purpose |
|---|---|
| `StringFileDownloader` | Downloads content as a text file |
| `MarkupFileDownloader` | Downloads HTML/markup content |

Uses `js-file-download` library for triggering browser downloads.

---

## HTML to Image Conversion

**Location**: `app/utils/htmlToImg/`

Uses `html-to-image` library to convert DOM elements to images. Factory pattern for different output formats.

Used for exporting visual content (charts, reports) as downloadable images.

---

## CSV Handling

### Parsing

```typescript
import Papa from 'papaparse';
// or
import { usePapaParse } from 'react-papaparse';
```

### Validation

`csv-file-validator` validates CSV structure before import.

---

## Media Playback

### react-player

Used for embedded video/audio playback within sessions:

```tsx
import ReactPlayer from 'react-player';

<ReactPlayer url={videoUrl} controls />
```

Questions can have `videoUrl` fields for multimedia content.

### Inline SVG

```tsx
import SVG from 'react-inlinesvg';

<SVG src={svgPath} />
```

Used throughout for icon rendering from SVG files.

---

## AppFile Model

The common file type used across the app:

```typescript
// app/models/File/
interface AppFile {
  id: string;
  name: string;
  url: string;
  // ... additional metadata
}
```

Used in: question images, SMS attachments, report templates, user avatars.

---

## Key Rules

- **Always use the `FileUpload` component** — don't build custom dropzone implementations
- **Respect `MAX_FILE_SIZE`** — the 5MB default applies unless explicitly overridden with `maxSize` or `maxSizeMap`
- **File uploads happen via sagas** — the component calls `onUpload` with the raw `File`, the parent dispatches an action, and the saga handles the API upload
- **Use `AppFile` type** — all file references in the Redux store and models use this interface, not raw `File` objects
