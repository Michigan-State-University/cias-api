# Animations & Narrator System

## Narrator / Character System

Sessions can have an animated narrator character that speaks and performs animations alongside questions. This is the most complex animation system in the app.

### Character: Peedy

The default character is "Peedy" — an animated parrot rendered with Lottie animations and voiced with Google TTS.

**Animation assets**: `app/assets/animations/peedy/`

Available animations:
- `standStill`, `acknowledge`, `eat`, `yawn`
- `pointRight`, `pointLeft`, `moveRight`
- `wearSunglasses`, `glanceLeft`, `glanceRight`
- `doMagic`, `decline`, `search`, `suggest`
- `reading`, `write`, `hearBothEars`
- `announceEnd`

### Session narrator settings

Each session has narrator configuration:

```typescript
settings: {
  narrator: {
    voice: boolean,     // enable Google TTS audio
    animation: boolean, // enable Lottie character animation
  },
}
```

### Narrator blocks

Each question has an array of `NarratorBlock` objects that define the narrator's behavior. Block types include body animations, head animations, speech, and pauses.

**Models**: `app/models/Narrator/`

### Animation Helpers (`app/utils/animationsHelpers/`)

| Hook | Purpose |
|---|---|
| `useAnimationHelper` | Manages Lottie animation loading, sequencing, idle states, block transitions |
| `useAudioHelper` | Manages Google TTS audio playback, speech synthesis, audio sequencing |
| `useFeedbackHelper` | Handles feedback-specific animation patterns |

Key concepts:
- **Animation loading**: Animations are imported dynamically and cached in a ref (`loadedAnimations`)
- **Block sequencing**: The narrator cycles through blocks, playing animations and audio in sequence
- **Idle animations**: When no block is active, the character plays an idle/rest animation
- **Auto-rest**: Body and head have separate auto-rest animation cycles

### Animation state management

```typescript
dispatchUpdate({
  currentData: ILoadedAnimationData,  // current animation JSON data
  currentBlockIndex: number,           // index in the narrator blocks array
})
```

## Lottie (react-lottie)

Used exclusively for the Peedy narrator character.

```tsx
import Lottie from 'react-lottie';

<Lottie
  ref={animationRef}
  options={{
    animationData: currentAnimation,
    loop: isIdle,
    autoplay: true,
  }}
/>
```

- Animations are JSON files loaded dynamically via `importAnimation()`
- Each animation has body and head variants
- `LottieRef` type for controlling playback

## Framer Motion

Used for **UI transitions**, not character animations:

```tsx
import { motion, AnimatePresence } from 'framer-motion';

<AnimatePresence>
  {visible && (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
    >
      {content}
    </motion.div>
  )}
</AnimatePresence>
```

Used in:
- File upload error/success states
- Component mount/unmount transitions
- Modal and popover animations

## Countdown Timers

Custom countdown components for session time limits:

- `CountdownCircleTimer` — visual circular countdown
- `CountdownTextTimer` — text-based countdown

Located in `app/components/` area.

## Google TTS (Text-to-Speech)

Sessions can have voice narration using Google TTS:

```typescript
interface GoogleTTSVoice {
  id: number;
  googleTtsLanguageId: number;
  voiceLabel: string;
  voiceType: string;
  languageCode: string;
}
```

- Configured per session via `session.googleTtsVoice`
- Audio playback managed by `useAudioHelper`
- Supports multiple languages

## Key Rules

- **Narrator is optional** — always check `session.settings.narrator.voice` and `.animation` before rendering narrator components
- **Animations load dynamically** — never import animation JSON statically; use `importAnimation()` which lazy-loads from the assets directory
- **Framer Motion is for UI only** — character animations use Lottie, not Framer Motion
- **Audio and animation are synchronized** — the block system ensures speech and character movement play together
- **Character type is extensible** — code references `CharacterType` from `models/Character`, allowing for future character additions
