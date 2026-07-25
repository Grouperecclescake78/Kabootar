/// Factual, public-domain civic content shown in the About screen. Kept in one
/// place so the wording stays accurate and easy to review.
abstract class Civic {
  /// The Preamble to the Constitution of India (adopted 26 November 1949).
  static const String preamble =
      'WE, THE PEOPLE OF INDIA, having solemnly resolved to constitute India '
      'into a SOVEREIGN SOCIALIST SECULAR DEMOCRATIC REPUBLIC and to secure to '
      'all its citizens:\n\n'
      'JUSTICE, social, economic and political;\n'
      'LIBERTY of thought, expression, belief, faith and worship;\n'
      'EQUALITY of status and of opportunity;\n'
      'and to promote among them all\n'
      'FRATERNITY assuring the dignity of the individual and the unity and '
      'integrity of the Nation;\n\n'
      'IN OUR CONSTITUENT ASSEMBLY this twenty-sixth day of November, 1949, do '
      'HEREBY ADOPT, ENACT AND GIVE TO OURSELVES THIS CONSTITUTION.';

  /// The Fundamental Duties of every citizen — Article 51A of the Constitution.
  static const List<String> fundamentalDuties = <String>[
    'Abide by the Constitution and respect its ideals and institutions, the '
        'National Flag and the National Anthem.',
    'Cherish and follow the noble ideals which inspired our national struggle '
        'for freedom.',
    'Uphold and protect the sovereignty, unity and integrity of India.',
    'Defend the country and render national service when called upon to do so.',
    'Promote harmony and the spirit of common brotherhood amongst all the '
        'people of India, transcending religious, linguistic, regional or '
        'sectional diversities; and renounce practices derogatory to the '
        'dignity of women.',
    'Value and preserve the rich heritage of our composite culture.',
    'Protect and improve the natural environment and have compassion for '
        'living creatures.',
    'Develop the scientific temper, humanism and the spirit of inquiry and '
        'reform.',
    'Safeguard public property and abjure violence.',
    'Strive towards excellence in all spheres of individual and collective '
        'activity.',
    'Provide opportunities for education to one’s child or ward between '
        'the ages of six and fourteen years.',
  ];

  /// Short, true facts shown as a rotating "Did you know?" line.
  static const List<String> facts = <String>[
    'India adopted its Constitution on 26 November 1949; it came into force on '
        '26 January 1950, celebrated as Republic Day.',
    'The Constitution of India is the longest written constitution of any '
        'sovereign country in the world.',
    'The Ashoka Chakra on the national flag has 24 spokes.',
    'Article 19(1)(a) guarantees every citizen the freedom of speech and '
        'expression.',
    'Kabootar keeps working with no internet by relaying messages phone to '
        'phone, so a message reaches you even in a signal dead-zone.',
    'Your messages, contacts and identity never leave your device - there '
        'is no server to hold them.',
    'A message you send can be carried by a stranger’s phone and delivered '
        'later, when the recipient comes back in range.',
    'No SIM and no internet needed: Bluetooth and Wi-Fi carry your message '
        'directly between phones.',
    'Create a channel and share its short code; anyone nearby who enters the '
        'code joins the same room, no servers, no links.',
    'The Eighth Schedule of the Constitution recognises 22 official '
        'languages of India.',
    'Every message carries a hop limit, so it spreads only as far as it '
        'usefully can, then stops.',
    'Fundamental Duties (Article 51A) ask every citizen to promote harmony '
        'and protect the environment.',
  ];

  /// Independent-project disclaimer. Important: this app is NOT affiliated with
  /// or endorsed by any government or political party.
  static const String disclaimer =
      'Kabootar is an independent, open-source project built in India by a '
      'citizen. It is not affiliated with, authorised by, or endorsed by the '
      'Government of India, any State Government, or any political party or '
      'organisation.\n\n'
      'The national tricolour and the Ashoka Chakra are used respectfully as a '
      'mark of national pride. We deliberately do not use the State Emblem of '
      'India (the Lion Capital), whose use is reserved for government '
      'authorities by law. The Preamble and Fundamental Duties are reproduced '
      'from the Constitution of India for civic and educational purposes.';
}
