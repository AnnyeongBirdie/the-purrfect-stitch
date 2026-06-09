# Bust-Up Portrait Generation Prompts
## For DesignerAna — ChatGPT / DALL-E

Bust-up portraits are used in the narrative dialogue HUD. Each portrait should:
- Show the character **from the chest up**, face centered and filling most of the frame
- Have a **transparent or plain very-dark/neutral background** (so it can be composited into the dialogue panel)
- Be **portrait orientation**, roughly 1:1.2 to 1:1.5 aspect ratio
- Match the **anime-influenced painterly illustration style** of the existing WizardCat and GodmotherCat sprites

**Workflow tip:** Generate Portrait_Daphne first. Then pass that image back to ChatGPT as a visual reference for the remaining three, asking it to match that exact style.

---

## Portrait_Daphne (재봉사 다프네)

> **Prompt:**
>
> Bust-up portrait of an adorable anthropomorphic orange tabby cat seamstress for a cozy fantasy mobile game. She has big expressive amber eyes, rounded chibi proportions, and a warm, cheerful expression. She wears a green dress with a lace collar, a yellow fabric measuring tape draped around her neck, and a small round pincushion hat with colorful pins on top of her head. She is holding a small pair of silver scissors in one paw. The portrait shows her from the chest up, face centered and filling the frame. Style: anime-influenced, painterly illustration with warm lighting, clean lines, soft shadows, highly detailed costume. Transparent background. Game dialogue portrait format.

---

## Portrait_Aurora (마법사 오로라)

> **Prompt:**
>
> Bust-up portrait of an elegant anthropomorphic white fluffy cat wizard named Aurora for a cozy fantasy mobile game. She has heterochromia — one eye is vivid emerald green and the other is deep blue. Rounded chibi proportions, and a wise, warm, slightly playful expression. She wears a deep purple wizard's hat with gold trim and a pink rose on the brim, and an elaborate purple and white robe with gold embroidery and lace detailing. A glowing blue-mint magical orb is faintly visible at the edge of the frame. The portrait shows her from the chest up, face centered and filling the frame. Style: anime-influenced, painterly illustration with cool magical lighting (mint-blue glow from the side), clean lines, soft shadows, highly detailed costume. Transparent background. Game dialogue portrait format.
>
> *(Pass the Portrait_Daphne result as a style reference image alongside this prompt.)*

---

## Portrait_Flora (요정 대모 플로라)

> **Prompt:**
>
> Bust-up portrait of a mysterious, regal anthropomorphic white fluffy cat fairy godmother for a cozy fantasy mobile game. She has **heterochromia**: one eye is warm gold, the other is soft blue-violet. Her expression is serene and knowing — gentle but otherworldly. She wears a tall conical silver hat with a sheer veil, and an intricate silver-white lace gown with crystal and diamond drop details. Her fur is pure white and luminous. A soft silver-white glow emanates from around her. The portrait shows her from the chest up, face centered and filling the frame. Style: anime-influenced, painterly illustration with cool silver lighting, clean lines, soft shadows, highly detailed costume. Transparent background. Game dialogue portrait format.
>
> *(Pass the Portrait_Daphne result as a style reference image alongside this prompt.)*

---

## Portrait_Ana (아나 공주)

> **Prompt:**
>
> Bust-up portrait of a sweet young anthropomorphic cat princess named Anastasia (Princess Ana) for a cozy fantasy mobile game. She is a cream or light golden tabby cat with big bright green eyes, rounded chibi proportions, and a warm, gentle, slightly wistful expression. She wears a lush emerald-green princess gown with gold trim and a delicate gold tiara with a small green jewel. Small white flowers are woven into her fur near one ear. The portrait shows her from the chest up, face centered and filling the frame. Style: anime-influenced, painterly illustration with warm green-tinted ambient lighting, clean lines, soft shadows, highly detailed costume. Transparent background. Game dialogue portrait format.
>
> *(Pass the Portrait_Daphne result as a style reference image alongside this prompt.)*

---

---

## Full-body sprite regenerations (style unification)

The Tailor and Shopkeeper were generated earlier in a simpler/flatter style. Regenerate them to match the painterly anime-influenced style of WizardCat and GodmotherCat. **Pass the WizardCat or GodmotherCat sprite as the style reference image** when generating these.

No code changes needed — just swap the PNGs in xcassets.

### Daphne / Tailor (full-body)

> **Prompt:**
>
> Full-body illustration of an adorable anthropomorphic orange tabby cat seamstress for a cozy fantasy mobile game. She has big expressive amber eyes, rounded chibi proportions, and a warm cheerful expression. She wears a green dress with a lace collar, a yellow fabric measuring tape draped around her neck, a small round pincushion hat with colorful pins on top of her head, and she holds a small pair of silver scissors in one paw and a piece of pink fabric in the other. Full body visible, standing pose, facing slightly toward the viewer. Style: anime-influenced, painterly illustration with warm lighting, clean lines, soft shadows, highly detailed costume — matching the style of the reference image. Transparent background. Game character sprite.
>
> *(Pass WizardCat or GodmotherCat as a style reference image alongside this prompt.)*

### Shopkeeper (full-body)

> **Prompt:**
>
> Full-body illustration of an adorable anthropomorphic orange tabby cat shopkeeper for a cozy fantasy mobile game. She has warm amber eyes, rounded chibi proportions, and a welcoming, pleasant expression. She wears a purple dress with a white apron, a pearl necklace, and a small blue hat with a pink flower. Her paws are clasped together in a friendly pose. Full body visible, standing pose, facing slightly toward the viewer. Style: anime-influenced, painterly illustration with warm lighting, clean lines, soft shadows, highly detailed costume — matching the style of the reference image. Transparent background. Game character sprite.
>
> *(Pass WizardCat or GodmotherCat as a style reference image alongside this prompt.)*

---

## Asset naming & sizing notes

Once generated, crop tightly and export as PNG with transparency. Suggested canvas size: **400 × 500 px** (@2x), naming:

| File | Asset in Xcode | Display name |
|---|---|---|
| `Portrait_Daphne.png` | `Portrait_Daphne.imageset` | 재봉사 다프네 |
| `Portrait_Aurora.png` | `Portrait_Aurora.imageset` | 마법사 오로라 |
| `Portrait_Flora.png` | `Portrait_Flora.imageset` | 요정 대모 플로라 |
| `Portrait_Ana.png` | `Portrait_Ana.imageset` | 아나 공주 |
