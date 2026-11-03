// Generated triage guidance data from First_Response_Guidance.docx.
// Contains all 93 guidance steps categorized into clean triage tiers.

import 'screening_result.dart' show Urgency;

/// Represents a single guidance action with its clinical rationale.
class GuidanceStep {
  final String action;
  final String reason;
  const GuidanceStep({required this.action, required this.reason});
}

/// Triage protocol for a specific skin condition.
class TriageProtocol {
  final String conditionLabel;
  /// Condition-level priority (static per condition), not patient-specific severity.
  final Urgency urgency;
  final String referralText;
  final List<GuidanceStep> startHere;
  final List<GuidanceStep> doNot;
  final List<GuidanceStep> homeCare;
  final List<GuidanceStep> monitoring;

  const TriageProtocol({
    required this.conditionLabel,
    required this.urgency,
    required this.referralText,
    required this.startHere,
    required this.doNot,
    required this.homeCare,
    required this.monitoring,
  });

  /// Total count of all guidance steps in this protocol.
  int get totalSteps =>
      startHere.length + doNot.length + homeCare.length + monitoring.length;
}

const Map<String, TriageProtocol> kConditionProtocols = {
  'FAD': TriageProtocol(
    conditionLabel: 'Flea allergy dermatitis',
    urgency: Urgency.medium,
    referralText: 'Refer to veterinarian',
    startHere: [
      GuidanceStep(
        action: 'Use a fine-toothed flea comb regularly to check for pests or flea waste in the fur.',
        reason: 'Combing reaches deep into the undercoat where visual checks might miss hiding fleas.',
      ),
      GuidanceStep(
        action: 'Wash all pet bedding, blankets, and fabric crate pads frequently in hot water.',
        reason: 'High thermal temperatures are required to kill flea eggs and larvae hiding in the fabric fibers.',
      ),
      GuidanceStep(
        action: 'Vacuum all carpets, rugs, upholstered furniture, and baseboards thoroughly.',
        reason: 'This physically pulls up developing flea pupae and cocoons embedded deep within carpet padding.',
      ),
    ],
    doNot: [
      GuidanceStep(
        action: 'Do not scratch, rub, or massage the raw skin with bare hands.',
        reason: 'Oils, dirt, and bacteria from your fingers can easily introduce secondary skin infections to the broken tissue.',
      ),
      GuidanceStep(
        action: 'Do not ignore minor scratching.',
        reason: 'An allergic dog reacts intensely to even a single bite, and delaying action allows the hypersensitivity reaction to spread rapidly.',
      ),
      GuidanceStep(
        action: 'Do not let the dog overheat or lie in damp, warm areas.',
        reason: 'Sweat and high humidity exacerbate skin inflammation and create an ideal breeding ground for bacteria.',
      ),
      GuidanceStep(
        action: 'Do not forget to inspect your own ankles and lower legs for flea activity.',
        reason: 'Fleas roaming the environment will readily bite humans if pet hosts are unavailable.',
      ),
      GuidanceStep(
        action: 'Do not wear open-toed shoes or shorts when cleaning or vacuuming pet areas.',
        reason: 'This prevents active fleas hiding in carpets or baseboards from biting your skin.',
      ),
      GuidanceStep(
        action: 'Do not shake out dirty pet bedding or fabric covers indoors.',
        reason: 'Shaking launches hidden flea eggs, larvae, and debris into the air and onto surrounding clean surfaces.',
      ),
      GuidanceStep(
        action: 'Do not let human clothing mix directly with the dog\'s contaminated bedding.',
        reason: 'This avoids transferring pests, allergens, and dander onto your personal garments.',
      ),
      GuidanceStep(
        action: 'Do not use heavily scented human shampoos or human lotions on irritated skin.',
        reason: 'Artificial fragrances and human pH balances will severely sting and worsen damaged canine skin barriers.',
      ),
    ],
    homeCare: [
      GuidanceStep(
        action: 'Empty the vacuum canister or discard the vacuum bag immediately outside in a sealed outdoor bin.',
        reason: 'Doing this ensures live fleas and hatching larvae cannot crawl back out into your home.',
      ),
      GuidanceStep(
        action: 'Restrict the dog\'s access to heavily carpeted areas during active flare-ups.',
        reason: 'Carpets act as major reservoirs for flea eggs and environmental allergens.',
      ),
      GuidanceStep(
        action: 'Keep lawn grass closely trimmed outdoors.',
        reason: 'This eliminates the shaded, humid microhabitats where outdoor fleas survive and multiply.',
      ),
      GuidanceStep(
        action: 'Prevent the dog from accessing damp, shaded outdoor zones where wildlife may drop fleas.',
        reason: 'Visiting stray animals or wildlife (like raccoons or rodents) frequently introduce new fleas to yards.',
      ),
      GuidanceStep(
        action: 'Inspect and clean outdoor resting zones like doghouses, porches, or patios regularly.',
        reason: 'This prevents environmental flea populations from building up right outside your door.',
      ),
      GuidanceStep(
        action: 'Bathe the dog using gentle, soap-free grooming products if approved, avoiding harsh chemicals.',
        reason: 'This soothes the skin surface without stripping away its natural protective lipids.',
      ),
      GuidanceStep(
        action: 'Pat the dog dry gently with a clean towel after baths rather than rubbing vigorously.',
        reason: 'Friction on inflamed skin causes further hair breakage and pain.',
      ),
      GuidanceStep(
        action: 'Avoid letting the dog sunbathe directly on raw, hairless patches of skin.',
        reason: 'Direct UV exposure can cause sunburn, thermal irritation, and secondary skin damage on unprotected tissue.',
      ),
      GuidanceStep(
        action: 'Clean grooming tools like brushes and combs thoroughly after every single session.',
        reason: 'This prevents re-infesting the dog with residual flea dirt or trapped pests left on the tools.',
      ),
      GuidanceStep(
        action: 'Maintain a clean, clutter-free living space to reduce areas where fleas can hide.',
        reason: 'Clutter provides dark, undisturbed zones for flea larvae to spin cocoons.',
      ),
    ],
    monitoring: [
      GuidanceStep(
        action: 'Watch out for frantic, relentless scratching, chewing, or biting directed at the lower back, tail base, thighs, and abdomen.',
        reason: 'These are the classic anatomical distribution zones where fleas congregate and trigger allergic flare-ups.',
      ),
      GuidanceStep(
        action: 'Watch out for localized hair loss (alopecia), red bumps (papules), and scabs.',
        reason: 'Constant self-trauma breaks the hair shafts and creates crusting skin lesions.',
      ),
      GuidanceStep(
        action: 'Watch out for hyperpigmentation (dark spots) or thickened, leathery skin resulting from chronic inflammation.',
        reason: 'Prolonged scratching causes long-term dermal thickening and pigment changes.',
      ),
      GuidanceStep(
        action: 'Watch out for live fleas or small black specks (flea dirt) moving in the fur.',
        reason: 'These serve as direct visual confirmation of the parasite population driving the allergic reaction.',
      ),
      GuidanceStep(
        action: 'Monitor skin integrity daily for open wounds, bleeding, or oozing from scratching.',
        reason: 'Broken skin can quickly turn into a deep bacterial infection requiring medical intervention.',
      ),
      GuidanceStep(
        action: 'Monitor whether the dog\'s sleep, eating habits, or normal resting routines are disrupted by intense itching.',
        reason: 'Unmanaged pruritus causes severe physical exhaustion and stress.',
      ),
      GuidanceStep(
        action: 'Monitor the intensity of the dog\'s scratching behavior using a daily mental or written log.',
        reason: 'This helps determine if environmental controls or grooming adjustments are successfully reducing their discomfort.',
      ),
      GuidanceStep(
        action: 'Monitor all other pets in the household simultaneously.',
        reason: 'An allergy in one animal indicates a shared parasite population present across the entire living space.',
      ),
      GuidanceStep(
        action: 'Comb the fur over a damp white paper towel to easily spot reddish flea dirt.',
        reason: 'Digested blood in flea feces dissolves on moisture and turns red, distinguishing it from ordinary dirt.',
      ),
      GuidanceStep(
        action: 'Check the lower back and tail base daily for new bumps, redness, or hair thinning.',
        reason: 'This catches early flare-ups before they escalate into raw, widespread wounds.',
      ),
    ],
  ),
  'Ringworm': TriageProtocol(
    conditionLabel: 'Dermatophytosis',
    urgency: Urgency.high,
    referralText: 'Refer to veterinarian',
    startHere: [
      GuidanceStep(
        action: 'Always wash your hands thoroughly with soap and water immediately after touching the dog.',
        reason: 'This mechanically rinses away any stray fungal spores before they can colonize your skin.',
      ),
      GuidanceStep(
        action: 'Wear disposable nitrile gloves and long sleeves when handling the dog or cleaning its space.',
        reason: 'This creates a physical barrier preventing spores from landing on your arms and hands.',
      ),
      GuidanceStep(
        action: 'Confine the infected dog to a dedicated, easily sanitized room away from other pets and family members.',
        reason: 'This limits the spread of contagious spores to a single, manageable area.',
      ),
    ],
    doNot: [
      GuidanceStep(
        action: 'Do not touch active ringworm lesions with bare hands.',
        reason: 'Ringworm is highly contagious (zoonotic) and skin-to-skin contact easily transfers fungal spores to humans.',
      ),
      GuidanceStep(
        action: 'Do not use the same towels, blankets, or linens for yourself after handling the dog.',
        reason: 'This prevents trapping and spreading microscopic fungal spores onto items you use on your own body.',
      ),
      GuidanceStep(
        action: 'Do not let the dog roam freely on carpets, couches, or beds while infected.',
        reason: 'Shedding hairs and skin scales constantly drop fungal spores onto soft furnishings, contaminating the entire home.',
      ),
      GuidanceStep(
        action: 'Do not shake out dirty pet bedding, blankets, or towels indoors.',
        reason: 'Sudden agitation launches millions of invisible fungal spores into the air to be inhaled or settle elsewhere.',
      ),
      GuidanceStep(
        action: 'Do not groom or brush affected hair patches.',
        reason: 'The physical action dislodges and scatters infectious spores into the immediate environment.',
      ),
      GuidanceStep(
        action: 'Do not clip or shave lesional hair without professional guidance.',
        reason: 'Clipping can create microscopic skin abrasions that drive the fungal infection deeper into surrounding tissue.',
      ),
      GuidanceStep(
        action: 'Do not let children or immunocompromised individuals handle the dog during recovery.',
        reason: 'Developing or suppressed immune systems are at a much higher risk of contracting severe ringworm infections.',
      ),
      GuidanceStep(
        action: 'Do not let the dog lick or rub against your face, hands, or clothing.',
        reason: 'Direct contact with infected facial hair or skin is a primary route of transmission to people.',
      ),
    ],
    homeCare: [
      GuidanceStep(
        action: 'Restrict other household pets from entering the isolation area or sharing toys and bowls.',
        reason: 'This prevents the fungal infection from jumping to other animals in the home.',
      ),
      GuidanceStep(
        action: 'Vacuum all hard floors, baseboards, and room perimeters daily using a HEPA-filtered vacuum.',
        reason: 'Standard vacuums exhaust microscopic spores back into the air, whereas HEPA filters trap them.',
      ),
      GuidanceStep(
        action: 'Change or clean vacuum bags and HEPA filters carefully in an outdoor receptacle.',
        reason: 'This prevents accumulated spores from escaping back indoors when handling waste.',
      ),
      GuidanceStep(
        action: 'Damp-mop hard flooring using microfiber mops that capture spores rather than scattering them dry.',
        reason: 'Dry sweeping lifts lightweight spores into the air.',
      ),
      GuidanceStep(
        action: 'Disinfect hard, non-porous surfaces and grooming tools after every single use.',
        reason: 'This kills residual spores lingering on bowls, crates, and cleaning equipment.',
      ),
      GuidanceStep(
        action: 'Keep grooming tools, brushes, and feeding bowls strictly separate from other pets.',
        reason: 'This eliminates cross-contamination between healthy and infected animals.',
      ),
      GuidanceStep(
        action: 'Bag disposable or non-cleanable contaminated toys and fabric items securely before throwing them away.',
        reason: 'This prevents spores from shedding into trash cans or during transport.',
      ),
      GuidanceStep(
        action: 'Launder isolation linens separately in hot water, drying them on high heat.',
        reason: 'High thermal temperatures destroy fungal spores effectively.',
      ),
      GuidanceStep(
        action: 'Keep human clothing away from the quarantine zone to prevent cross-contamination.',
        reason: 'This ensures you do not accidentally carry spores out into common living areas on your clothes.',
      ),
      GuidanceStep(
        action: 'Keep doors to the isolation room securely closed at all times.',
        reason: 'This physically blocks curious pets or children from wandering into the contaminated zone.',
      ),
      GuidanceStep(
        action: 'Wear dedicated shoes or shoe covers inside the isolation area if necessary.',
        reason: 'Doing so prevents you from tracking fungal spores out on the soles of your shoes across household carpets.',
      ),
      GuidanceStep(
        action: 'Clean door handles and light switches in and around the quarantine zone frequently.',
        reason: 'Hands touching these high-contact areas can deposit and pick up spores.',
      ),
      GuidanceStep(
        action: 'Wash your face and arms after spending time inside the quarantine area.',
        reason: 'This removes any invisible airborne spores that settled on your skin during interaction.',
      ),
    ],
    monitoring: [
      GuidanceStep(
        action: 'Watch out for circular or irregular patches of hair loss where individual hair appears brittle or broken flush with the skin.',
        reason: 'Dermatophytes weaken hair shafts until they snap off right at the surface.',
      ),
      GuidanceStep(
        action: 'Watch out for dry, scaly, or crusty skin centers surrounded by a reddened perimeter.',
        reason: 'The fungus typically grows outward in a ring pattern while healing in the middle.',
      ),
      GuidanceStep(
        action: 'Watch out for brittle, split, or deformed claws if the fungal infection extends to nail beds.',
        reason: 'Certain dermatophyte strains attack keratin structures like claws just as they do hair.',
      ),
      GuidanceStep(
        action: 'Monitor whether circular patches are expanding or multiplying across different parts of the body.',
        reason: 'This tracks if the fungal infection is actively spreading or remaining contained.',
      ),
      GuidanceStep(
        action: 'Monitor household members (especially children) for sudden, itchy, red, ring-shaped skin rashes.',
        reason: 'Doing so ensures any human transmission is caught and treated early.',
      ),
      GuidanceStep(
        action: 'Monitor the dog\'s general stress levels while in isolation by providing safe interaction and environmental enrichment.',
        reason: 'Isolation can cause anxiety that negatively impacts immune health.',
      ),
      GuidanceStep(
        action: 'Keep a visual log or take photos of the lesions to track changes over time.',
        reason: 'This helps you notice if skin borders are shrinking or spreading during recovery.',
      ),
    ],
  ),
  'Hotspot': TriageProtocol(
    conditionLabel: 'Hotspot (acute moist dermatitis)',
    urgency: Urgency.high,
    referralText: 'Refer to veterinarian',
    startHere: [
      GuidanceStep(
        action: 'Keep the area completely uncovered and exposed to open air.',
        reason: 'Doing so allows natural evaporation to dry out the moist skin environment.',
      ),
      GuidanceStep(
        action: 'Ensure the barrier collar fits correctly so the dog cannot reach the lesion from any angle.',
        reason: 'Even a slight gap allows a flexible dog to resume licking the wound.',
      ),
      GuidanceStep(
        action: 'Keep the dog in a cool, low-humidity indoor environment.',
        reason: 'High room temperatures and humidity promote sweating and moisture retention in the coat.',
      ),
    ],
    doNot: [
      GuidanceStep(
        action: 'Do not leave the dog unsupervised without a barrier collar (E-collar or recovery suit).',
        reason: 'Hot spots expand exponentially within minutes if the dog is allowed to lick or chew the site.',
      ),
      GuidanceStep(
        action: 'Do not rub, scrub, or massage a hot spot with your hands.',
        reason: 'The skin tissue is raw, inflamed, and intensely painful, and pressure will trigger defensive biting or aggression.',
      ),
      GuidanceStep(
        action: 'Do not cover a hot spot with tight bandages, tight clothing, or heavy occlusive ointments.',
        reason: 'Hot spots require open air to dry out; trapping moisture underneath bandages accelerates bacterial growth.',
      ),
      GuidanceStep(
        action: 'Do not let the dog swim or stay out in wet weather until the skin is fully healed.',
        reason: 'Moisture trapped in the coat is the primary trigger that initiates hot spot formation.',
      ),
      GuidanceStep(
        action: 'Do not ignore a foul odor or active oozing coming from the skin surface.',
        reason: 'These are clear indicators of a worsening secondary bacterial infection.',
      ),
      GuidanceStep(
        action: 'Do not use harsh scented shampoos, human soaps, or irritating sprays on or near the wound.',
        reason: 'Chemicals will burn raw tissue and drastically increase local inflammation.',
      ),
      GuidanceStep(
        action: 'Do not let the dog rub against furniture, walls, or carpets to scratch the itchy area.',
        reason: 'Friction from household surfaces will tear delicate skin and worsen the wound.',
      ),
    ],
    homeCare: [
      GuidanceStep(
        action: 'Blow-dry dense undercoats thoroughly down to the skin level after any water exposure.',
        reason: 'Leaving the undercoat damp against the skin is a direct invitation for bacterial proliferation.',
      ),
      GuidanceStep(
        action: 'Prevent other household pets from licking or grooming the hot spot.',
        reason: 'Saliva from other animals introduces new bacteria and keeps the wound wet.',
      ),
      GuidanceStep(
        action: 'Use a soft towel to gently dab away excess moisture only if advised, without wiping aggressively.',
        reason: 'This avoids tearing fragile, inflamed skin cells.',
      ),
      GuidanceStep(
        action: 'Keep the dog\'s resting area clean, dry, and cool.',
        reason: 'This prevents dust, dirt, and humidity from aggravating the exposed skin.',
      ),
      GuidanceStep(
        action: 'Keep the dog calm and quiet to minimize physical exertion.',
        reason: 'Heavy exercise raises body temperature, increases panting, and creates sweat that irritates healing skin.',
      ),
      GuidanceStep(
        action: 'Clean and brush the rest of the coat regularly to prevent matting.',
        reason: 'This ensures air can circulate freely across all parts of the body.',
      ),
    ],
    monitoring: [
      GuidanceStep(
        action: 'Watch out for a sharply defined, wet, shiny, and oozing lesion that appears suddenly.',
        reason: 'Hot spots develop at an alarming speed—often within just a few hours.',
      ),
      GuidanceStep(
        action: 'Watch out for rapid hair loss directly over and surrounding the wet patch.',
        reason: 'Inflammation and constant moisture cause hair follicles to loosen and shed instantly.',
      ),
      GuidanceStep(
        action: 'Watch out for noticeable heat radiating from the skin tissue.',
        reason: 'Active localized inflammation causes a sharp increase in skin temperature.',
      ),
      GuidanceStep(
        action: 'Watch out for intense, obsessive licking, biting, or scratching focused squarely on a single spot.',
        reason: 'This repetitive self-trauma is both the cause and accelerator of acute moist dermatitis.',
      ),
      GuidanceStep(
        action: 'Measure and record the outer boundaries of the wet patch daily.',
        reason: 'This helps verify whether the lesion is shrinking or continuing to spread outward.',
      ),
      GuidanceStep(
        action: 'Observe whether the lesion transitions from a wet exudate to a dry, flat surface.',
        reason: 'This indicates that the acute infection is beginning to recede.',
      ),
      GuidanceStep(
        action: 'Inspect dense undercoats regularly, especially after swimming or bathing.',
        reason: 'This catches trapped moisture before it triggers a sudden hot spot breakout.',
      ),
      GuidanceStep(
        action: 'Check surrounding areas for hidden triggers like matted fur or trapped moisture.',
        reason: 'These block air circulation and trap sweat against the skin.',
      ),
      GuidanceStep(
        action: 'Inspect the dog\'s ears carefully for signs of discomfort, scratching, or head-shaking.',
        reason: 'Ear infections cause dogs to scratch furiously at their head and neck, resulting in facial or neck hot spots.',
      ),
      GuidanceStep(
        action: 'Check the rear and tail base area if posterior hot spots develop.',
        reason: 'Anal gland irritation or flea bites in that region frequently prompt dogs to chew themselves raw there.',
      ),
      GuidanceStep(
        action: 'Monitor the dog\'s overall behavior for restlessness, whining, or lethargy due to pain.',
        reason: 'Hot spots cause significant localized discomfort and stress.',
      ),
      GuidanceStep(
        action: 'Monitor the dog while eating or drinking to ensure the barrier collar doesn\'t cause distress or get soiled.',
        reason: 'This prevents food or water from pooling inside the collar and dripping onto the neck.',
      ),
      GuidanceStep(
        action: 'Check the dog\'s paws and skin folds daily for any secondary moisture pockets.',
        reason: 'Dogs often shift their licking or develop concurrent moisture traps elsewhere when stressed.',
      ),
      GuidanceStep(
        action: 'Keep a written or photographic record of the lesion\'s healing progress daily.',
        reason: 'This allows you to objectively track whether the condition is improving or requiring veterinary attention.',
      ),
      GuidanceStep(
        action: 'Watch for any signs of spreading or new hot spots developing nearby.',
        reason: 'Dogs with sensitive skin can develop multiple lesions simultaneously if the underlying trigger is not addressed.',
      ),
    ],
  ),
};
