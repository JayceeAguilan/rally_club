# Design System Document: Athletic Editorial



## 1. Overview & Creative North Star

The "Creative North Star" for this design system is **The Kinetic Court.**



Unlike standard management apps that feel like spreadsheets, this system captures the high-energy, fast-paced motion of pickleball through an editorial lens. It rejects the "boxy" nature of traditional SaaS in favor of a fluid, layered experience. We achieve a "premium athletic" feel by utilizing aggressive white space, bold typography scales, and a departure from structural lines. The interface should feel as aerodynamic and intentional as a professional paddle.



**Key Design Principles:**

* **Asymmetric Energy:** Break the center-aligned grid. Use left-heavy typography paired with right-aligned floating elements to create a sense of forward motion.

* **High-Visibility Contrast:** Designed for the "Court-Side Reality." This system prioritizes extreme legibility under direct sunlight using maximum tonal range between surfaces and text.

* **Tonal Fluidity:** We eliminate rigid borders. Sections are defined by shifts in "atmospheric" color, creating a seamless, high-end digital environment.



---



## 2. Colors: The High-Vis Palette

The palette is anchored by a high-octane "Pickleball Green" and a sophisticated Deep Navy.



### The Core Tokens

* **Primary (`#4e6300` / `#cafd00`):** Our "Pickleball Green." Use the `primary_container` (`#cafd00`) for high-impact actions. It is the color of the ball and the energy of the game.

* **Surface Hierarchy:** We utilize a "Nested Surface" logic.

* **Background (`#f4f6ff`):** The base canvas.

* **Surface Container Lowest (`#ffffff`):** Reserved for the most important interactive cards.

* **Surface Container High (`#d5e3ff`):** Used for secondary grouping or "sunken" layout sections.



### The "No-Line" Rule

**Explicit Instruction:** Designers are prohibited from using 1px solid borders to define sections or cards. Boundaries must be defined solely through background color shifts. For example, a card (`surface_container_lowest`) must sit on a `surface_container_low` background. This creates a modern, architectural depth that feels custom-built, not templated.



### Signature Textures & Glass

To elevate the "Modern" feel, use **Glassmorphism** for floating action buttons or navigation overlays.

* **The Frosted Court:** Apply `surface` color at 70% opacity with a `20px` backdrop-blur. This ensures the vibrant primary green of the content "bleeds" through the UI, maintaining a sense of place.

* **The Kinetic Gradient:** For hero CTAs, use a linear gradient from `primary` (`#4e6300`) to `primary_container` (`#cafd00`) at a 135-degree angle to mimic the flash of a paddle swing.



---



## 3. Typography: Editorial Authority

We use a dual-font strategy to balance athletic aggression with functional clarity.



* **Display & Headlines (Lexend):** A geometric sans-serif that feels expansive and confident.

* `display-lg` (3.5rem): Reserved for scoreboards and hero stats.

* `headline-md` (1.75rem): Used for section headers.

* **Body & Labels (Inter):** The workhorse for readability.

* `body-lg` (1rem): Standard court booking details.

* `label-sm` (0.6875rem): Meta-data and micro-copy.



**Editorial Style Tip:** Always pair a `display-sm` headline with a `label-md` uppercase sub-header (using `on_surface_variant`). The contrast in scale creates an "Elite Club" aesthetic.



---



## 4. Elevation & Depth: Tonal Layering

Traditional shadows are often "dirty." In this system, we use **Ambient Depth.**



* **The Layering Principle:** Stacking surfaces creates hierarchy. Place a `surface_container_lowest` card on a `surface_container_low` section to create a soft, natural lift without a single pixel of shadow.

* **Ambient Shadows:** When a floating element (like a modal) is required, use a 4% opacity shadow tinted with `secondary` (`#535b71`). Blur values must be high (32px+) to mimic natural stadium lighting.

* **The Ghost Border Fallback:** If high-contrast accessibility is required, use the `outline_variant` token at **15% opacity**. Never use 100% opaque lines.



---



## 5. Components: Functional Precision



### Buttons: The "Paddle" Style

* **Primary:** `primary_container` background with `on_primary_container` text. Corners set to `md` (0.75rem). Use a subtle inner-glow (white at 10% opacity) on the top edge to simulate 3D volume.

* **Secondary:** `surface_container_highest` background. No border.



### Input Fields: High-Visibility

* **Style:** No bottom line or full border. Use a solid `surface_container_low` background with a `md` (0.75rem) corner radius.

* **Active State:** The background remains static, but the label shifts to `primary` green.



### Cards & Lists: The No-Divider Rule

* **Forbid Dividers:** Horizontal lines are strictly banned. Use the **Spacing Scale** (specifically `spacing-4` or `spacing-6`) to create distinct groupings through "active white space."

* **Club Cards:** Use `surface_container_lowest` for a "popping" effect against the `background`.



### Custom Contextual Components

* **Live Score Ticker:** A full-bleed `inverse_surface` bar using `primary_fixed` (`#cafd00`) typography for real-time court scores.

* **Availability Heatmap:** Use a tonal scale from `surface_container` (unavailable) to `primary` (available) to show court density.



---



## 6. Do's and Don'ts



### Do:

* **Use Asymmetry:** Place large-scale typography (e.g., a "01" court number) partially off-grid to create an athletic feel.

* **Embrace Large Radii:** Stick to the `md` (0.75rem) and `lg` (1rem) tokens for a friendly, modern "club" vibe.

* **Design for Sunlight:** Check contrast ratios against `on_background` for all outdoor-use screens.



### Don't:

* **Don't use 1px borders.** It immediately cheapens the "Editorial" feel.

* **Don't use pure black.** Use `on_background` (`#242f41`) for text to maintain the sophisticated Navy/Charcoal undertone.

* **Don't crowd the court.** If a screen feels busy, double the spacing values. Precision requires breathing room.