# Design System Specification: The "Kinetic Sanctuary"

## 1. Overview & Creative North Star: "Kinetic Sanctuary"
The design system for this platform is anchored by the **Kinetic Sanctuary** North Star. In the fast-paced world of last-mile logistics within Najaf and Mosul, our UI must serve as a calm, authoritative haven. We move away from the "cluttered utility" of traditional delivery apps, opting instead for a **High-End Editorial** approach.

We break the "template" look by utilizing intentional asymmetry, overlapping map elements, and a radical departure from traditional containment. We prioritize "breathing room" (generous whitespace) and tonal depth to ensure the experience feels premium, local, and obsessively curated.

---

## 2. Colors: Tonal Architecture
Color is used here as a structural element, not just an accent. We rely on Material 3 tonal palettes to ensure harmonic transitions.

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders for sectioning or grouping. 
- **The Strategy:** Define boundaries solely through background color shifts. For example, a `surface-container-low` section should sit directly on a `surface` background. The shift in tone provides all the visual affordance needed without the "cheapening" effect of lines.

### Surface Hierarchy & Nesting
Treat the UI as physical layers of fine paper or frosted glass.
- **Nesting:** To create depth, stack containers. Place a `surface-container-lowest` card (the lightest/highest) inside a `surface-container-low` section. This creates a "soft lift" that feels architectural rather than digital.
- **The Glass & Gradient Rule:** For floating map overlays or navigation bars, use **Glassmorphism**. Apply `surface` colors at 70% opacity with a `24px` backdrop blur. 
- **Signature Textures:** Use subtle linear gradients for CTAs: `primary` (#00666d) to `primary_container` (#00818a) at a 135-degree angle. This adds "soul" and prevents the buttons from looking flat.

---

## 3. Typography: Editorial Authority
We utilize **Tajawal** (and Manrope for English numerals/fallback) to bridge the gap between traditional Arabic calligraphy and modern geometry.

*   **Display (3.5rem / 56px):** Used for "Arrival" times or "Hero" stats. Bold, assertive, and slightly tracked-in for a tight, premium feel.
*   **Headline (2rem / 32px):** Used for page titles. The "Local" soul of the app lives here.
*   **Title (1.125rem / 18px):** Medium weight. Used for restaurant names or delivery stages.
*   **Body (1rem / 16px):** Standard tracking. Optimized for readability in both RTL and LTR.
*   **Label (0.75rem / 12px):** All-caps for English or Bold for Arabic to denote status (e.g., "ON THE WAY").

**Editorial Contrast:** Use `display-lg` in `primary` color next to a `body-sm` in `on-surface-variant` to create a high-contrast, professional hierarchy that feels like a luxury magazine.

---

## 4. Elevation & Depth: The Layering Principle
We move beyond the "Drop Shadow" by using **Tonal Layering**.

*   **The Layering Principle:** Depth is achieved by stacking the surface-container tiers. 
    *   *Base:* `surface`
    *   *Section:* `surface-container-low`
    *   *Card:* `surface-container-lowest`
*   **Ambient Shadows:** When a card must "float" (e.g., a map pin detail), use an extra-diffused shadow: `Y: 8px, Blur: 24px, Color: on-surface @ 6%`. In Dark Mode, replace shadows with a `subtle-glow`: a 1px `outline-variant` at 10% opacity and a soft outer glow of the `primary` color at 5% opacity.
*   **The "Ghost Border" Fallback:** If a container sits on an identical color background, use a "Ghost Border": `outline-variant` at **15% opacity**. Never use 100% opaque lines.

---

## 5. Components: Functional Elegance

### Buttons (The "Precision Tool")
*   **Primary:** Rounded `12px` (as per scale `md`). Gradient fill. No border. High-elevation shadow on tap.
*   **Secondary:** `surface-container-high` background with `on-secondary-container` text.
*   **Tertiary:** Text-only with an underline that is actually a 2px `primary_fixed` bar, offset by 4px.

### Cards (The "Container")
*   **Corner Radius:** Always `16px` (scale `lg`).
*   **Constraint:** Forbid divider lines within cards. Separate the "Order Total" from "Items" using a `16px` vertical gap and a slight background tint change to `surface-container-highest`.

### Map Overlays (The "Glass" Layer)
*   For delivery tracking, overlays must use Glassmorphism. 
*   **Styles:** `surface` at 80% opacity, `backdrop-filter: blur(12px)`.

### Inputs (The "Interaction")
*   **Active State:** Instead of a thick border, use a `2px` bottom-bar in `primary` and a subtle `primary-fixed` background tint.

---

## 6. Do's and Don'ts

### Do:
*   **DO** use RTL-specific iconography (e.g., arrows that flip direction for Arabic).
*   **DO** use "Surface Dim" for inactive background states to make the "Surface Bright" active cards pop.
*   **DO** leave at least 24px of padding on the horizontal edges of the iPhone 14 Pro layout to maintain the "Editorial" feel.

### Don't:
*   **DON'T** use pure black (#000000). Use `inverse_surface` (#2e3132) for deep tones to keep the "Premium" softness.
*   **DON'T** use 1px dividers to separate list items. Use whitespace or a `4px` height `surface-container` block.
*   **DON'T** use "Standard Blue" for links. Always use the signature `primary` teal (#00666d) or `secondary` deep blue (#3755c3).

---

## 7. Delivery Context (Najaf & Mosul)
Ensure that maps highlight local landmarks with custom `secondary` color markers. The UI must feel "local" by respecting RTL flow as the primary orientation—leading with the right side for all major navigation triggers and status updates.