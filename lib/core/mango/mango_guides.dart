/// Ask Mango: predefined, offline walkthroughs (no AI). Each step points at a
/// widget by the text or tooltip it shows on screen, so guides need no hooks in
/// the screens themselves. Keep step text short: one action per step.
library;

/// Who is using the app; guides are offered only where they make sense.
enum MangoAudience { guest, owner, manager, customer, driver }

class MangoStep {
  /// Labels to spotlight (first visible match wins). Empty = a text-only step.
  final List<String> targets;
  final String text;

  /// Tapping the spotlighted widget moves to the next step. Off for text
  /// fields, where the user needs to type first.
  final bool advanceOnTap;

  const MangoStep(this.targets, this.text, {this.advanceOnTap = true});
  const MangoStep.say(this.text)
      : targets = const [],
        advanceOnTap = false;
}

class MangoGuide {
  final String id;
  final String title;
  final Set<MangoAudience> audiences;

  /// If any of these labels is on screen, the guide is "for this screen".
  final List<String> contextTexts;
  final List<MangoStep> steps;

  const MangoGuide({
    required this.id,
    required this.title,
    required this.audiences,
    required this.steps,
    this.contextTexts = const [],
  });
}

const _sellers = {MangoAudience.owner, MangoAudience.manager};

/// The next-step button on an order shows one of these labels.
const _orderNextAction = [
  'Add Delivery Address First',
  'Confirm Order',
  'Start Loading',
  'Complete Loading',
  'Create Dispatch',
  'View Dispatch',
];

const mangoGuides = <MangoGuide>[
  MangoGuide(
    id: 'signup',
    title: 'Sign up or log in',
    audiences: {MangoAudience.guest},
    contextTexts: ['Welcome to GreenRoot'],
    steps: [
      MangoStep(
        // The hint sits inside the field (spotlights the box); label once typed.
        ['9876543210', 'Mobile Number'],
        'Type your 10-digit mobile number in this box.',
        advanceOnTap: false,
      ),
      MangoStep(
        ['I agree to the'],
        'Tick the box to accept the terms.',
        advanceOnTap: false,
      ),
      MangoStep(
        ['Send OTP'],
        'Tap Send OTP. We send a 6-digit code to your phone.',
      ),
      MangoStep.say(
          'Enter the code, add your name, then choose how you will use '
          'GreenRoot: nursery owner, manager, customer or driver.'),
    ],
  ),
  MangoGuide(
    id: 'register_nursery',
    title: 'Register my nursery',
    audiences: {MangoAudience.customer},
    contextTexts: ['Register Your Nursery'],
    steps: [
      MangoStep(['Open profile'], 'Open your profile.'),
      MangoStep(['Register Your Nursery'], 'Tap Register Your Nursery.'),
      MangoStep.say('Fill in the nursery name and address, then Submit. '
          'GreenRoot reviews it and you can start selling.'),
    ],
  ),
  MangoGuide(
    id: 'become_driver',
    title: 'Become a driver',
    audiences: {MangoAudience.customer},
    contextTexts: ['Become a Driver'],
    steps: [
      MangoStep(['Open profile'], 'Open your profile.'),
      MangoStep(['Become a Driver'], 'Tap Become a Driver.'),
      MangoStep.say('Enter your licence and vehicle number and submit. '
          'After approval you can join delivery trips.'),
    ],
  ),
  MangoGuide(
    id: 'post_ad',
    title: 'Post a plant ad',
    audiences: _sellers,
    contextTexts: ['Create a Plant Ad', 'Local Market'],
    steps: [
      MangoStep(['Market'], 'Open the Market tab.'),
      MangoStep(['Create a Plant Ad'], 'Tap Create a Plant Ad.'),
      MangoStep(
        ['Plants I Have', 'Plants I Want'],
        'Pick Plants I Have to sell, or Plants I Want to buy.',
      ),
      MangoStep.say('Choose the plant, quantity and price, add up to 3 photos, '
          'then Publish. Keep location on so nearby nurseries find it.'),
    ],
  ),
  MangoGuide(
    id: 'search_nearby',
    title: 'Find plants near me',
    audiences: _sellers,
    contextTexts: ['Search market listings', 'Local Market'],
    steps: [
      MangoStep(['Market'], 'Open the Market tab.'),
      MangoStep(
        ['Search market listings'],
        'Search by plant name here.',
        advanceOnTap: false,
      ),
      MangoStep(
        ['For sale', 'Wanted'],
        'Switch between plants for sale and plants people want.',
      ),
      MangoStep(['Change'], 'Change how far around you to look.'),
    ],
  ),
  MangoGuide(
    id: 'browse_customer',
    title: 'Find plants and nurseries',
    audiences: {MangoAudience.customer},
    contextTexts: ['Browse Plants', 'My Nurseries', 'Explore Nurseries'],
    steps: [
      MangoStep(
        ['Browse Plants'],
        'Tap Browse Plants to see what nurseries have.',
      ),
      MangoStep.say(
        'Or see nurseries on Home: My Nurseries, or Explore Nurseries if '
        'you have none yet.',
      ),
    ],
  ),
  MangoGuide(
    id: 'contact_seller',
    title: 'Contact a seller',
    audiences: _sellers,
    contextTexts: ['Chat with seller', 'I have this', 'Open chat'],
    steps: [
      MangoStep(['Market'], 'Open the Market tab.'),
      MangoStep.say('Tap any ad to open it.'),
      MangoStep(
        ['Chat with seller', 'I have this', 'Open chat'],
        'Tap here to send the seller a message or an offer.',
      ),
      MangoStep(['Chats'], 'Your conversations are all under Chats.'),
    ],
  ),
  MangoGuide(
    id: 'quotation_seller',
    title: 'Send a quotation',
    audiences: _sellers,
    contextTexts: ['New Quotation', 'Save Draft', 'Send to Customer'],
    steps: [
      MangoStep(['New Quotation'], 'On Home, tap New Quotation.'),
      MangoStep(
        ['Prepare and share with customer'],
        'Choose Quotation to prepare one for a customer.',
      ),
      MangoStep(['Select connected customer...'], 'Pick the customer.'),
      // The plant, quantity and price fields sit around Add Item; a spotlight on
      // the button alone would block them.
      MangoStep.say(
        'Fill in the plant, quantity and price. Tap Add Item for more plants.',
      ),
      MangoStep(['Save Draft'], 'Save the draft.'),
      MangoStep.say(
          'Open the draft and tap Send to Customer. When they accept, '
          'tap Convert to Order.'),
    ],
  ),
  MangoGuide(
    id: 'quotation_customer',
    title: 'Answer a quotation',
    audiences: {MangoAudience.customer},
    contextTexts: ['My Purchases'],
    steps: [
      MangoStep(['Buying'], 'Open Buying.'),
      MangoStep(['Quotations'], 'Quotations from nurseries are here.'),
      MangoStep(
        ['Accept', 'Decline'],
        'Tap Accept to order, or Decline (you can give a reason).',
      ),
    ],
  ),
  MangoGuide(
    id: 'order_seller',
    title: 'Move an order forward',
    audiences: _sellers,
    contextTexts: ['Order Timeline', ..._orderNextAction],
    steps: [
      MangoStep(['Selling', 'Work'], 'Open your orders.'),
      MangoStep(['Orders'], 'Tap the Orders tab.'),
      MangoStep.say('Open an order.'),
      MangoStep(
        _orderNextAction,
        'This glowing button is always the next step: confirm, load, then '
        'dispatch.',
      ),
      MangoStep(['Order Timeline'], 'The timeline shows what is done so far.'),
    ],
  ),
  MangoGuide(
    id: 'order_status_customer',
    title: 'Track my order',
    audiences: {MangoAudience.customer},
    contextTexts: ['My Purchases', 'Track Delivery'],
    steps: [
      MangoStep(['Buying'], 'Open Buying.'),
      MangoStep(['Orders'], 'Your orders and their status are here.'),
      MangoStep(['Deliveries'], 'Deliveries shows trips on the way to you.'),
    ],
  ),
  MangoGuide(
    id: 'driver_trip',
    title: 'Do a delivery trip',
    audiences: {MangoAudience.driver},
    contextTexts: [
      'Join Trip',
      'Start Journey',
      'Continue Trip',
      'Complete Delivery',
    ],
    steps: [
      MangoStep(
        ['Scan'],
        'Tap Scan and point at the trip QR the nursery shows you.',
      ),
      MangoStep.say(
        'Or paste the trip code the nursery sent under Join a Trip on Home. Then tap Accept Trip.',
      ),
      MangoStep(
        ['Start Journey', 'Continue Trip'],
        'When the plants are loaded, start the journey.',
      ),
      MangoStep(['Upload Proof'], 'At the customer, take a proof photo.'),
      MangoStep(['Complete Delivery'], 'Then tap Complete Delivery.'),
    ],
  ),
];

/// Guides this audience may use.
List<MangoGuide> guidesFor(MangoAudience audience) => [
      for (final g in mangoGuides)
        if (g.audiences.contains(audience)) g,
    ];

/// Guides for [audience], the ones matching what is on screen first.
List<({MangoGuide guide, bool here})> rankGuides(
  MangoAudience audience,
  bool Function(String label) onScreen,
) {
  final all = [
    for (final g in guidesFor(audience))
      (guide: g, here: g.contextTexts.any(onScreen)),
  ];
  return [...all.where((e) => e.here), ...all.where((e) => !e.here)];
}
