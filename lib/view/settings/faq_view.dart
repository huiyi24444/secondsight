import 'package:flutter/material.dart';
import 'package:secondsight/view/widgets/custom_back_button.dart';

class FAQView extends StatelessWidget {
  const FAQView({super.key});

  @override
  Widget build(BuildContext context) {
    final faqData = [
      {
        'category': '🛍️ About SecondSight',
        'questions': [
          {
            'question': 'What is SecondSight?',
            'answer': 'SecondSight is a sustainable fashion platform where we sell curated second-hand clothing directly from our own company. Each item is hand-checked for quality, cleanliness, and style.'
          },
          {
            'question': 'Is SecondSight a marketplace or a store?',
            'answer': 'We are not a marketplace — all clothing is sold and managed by SecondSight. This allows us to ensure consistent quality and service.'
          },
        ]
      },
      {
        'category': '👚 Virtual Try-On',
        'questions': [
          {
            'question': 'How does the virtual try-on feature work?',
            'answer': 'Our virtual try-on uses advanced AR technology that lets you see how clothes would look on you using your device\'s camera or an uploaded photo. It helps you gauge fit, style, and overall look before purchasing.'
          },
          {
            'question': 'Do I need to install an app to use virtual try-on?',
            'answer': 'No installation is required! The virtual try-on works directly in your mobile device through our app.'
          },
          {
            'question': 'Is virtual try-on accurate?',
            'answer': 'While it provides a realistic visualization, virtual try-on is a style aid — it does not guarantee perfect fit. Please always refer to the item\'s size measurements before purchase.'
          },
        ]
      },
      {
        'category': '📦 Orders & Shipping',
        'questions': [
          {
            'question': 'How do I place an order?',
            'answer': 'Simply browse the app, add items to your cart, and proceed to checkout. All items are one-of-a-kind, so grab what you love before it\'s gone!'
          },
          {
            'question': 'How long does shipping take?',
            'answer': 'We process and ship orders within 1–3 business days. Delivery time depends on your location but typically ranges from 3–7 business days.'
          },
          {
            'question': 'Do you ship internationally?',
            'answer': 'Currently, we do not ship internationally. However, we are working on expanding our shipping zones soon!'
          },
        ]
      },
      {
        'category': '🔄 Returns & Exchanges',
        'questions': [
          {
            'question': 'Can I return a second-hand item?',
            'answer': 'Yes! We accept returns within 5 days of delivery if the item doesn\'t meet your expectations. Items must be in original condition. Please review our full Return Policy for details.'
          },
          {
            'question': 'Do you offer exchanges?',
            'answer': 'Since most items are unique, we cannot offer direct exchanges. However, you may return the item and place a new order.'
          },
        ]
      },
      {
        'category': '🌿 Sustainability & Quality',
        'questions': [
          {
            'question': 'Are all items cleaned before being sold?',
            'answer': 'Absolutely. Every item is professionally cleaned, inspected, and photographed before listing.'
          },
          {
            'question': 'How do you ensure the quality of second-hand clothes?',
            'answer': 'Our team hand-selects and inspects each piece. Only items in good to excellent condition are accepted.'
          },
        ]
      },
      {
        'category': '🔧 Account & Support',
        'questions': [
          {
            'question': 'Do I need an account to shop?',
            'answer': 'No account is required to shop, but creating one lets you track orders, save favorites, and receive special offers.'
          },
          {
            'question': 'How can I contact support?',
            'answer': 'You can reach us through our Contact Us page or email us at support@secondsight.com. We respond within 24 hours on business days.'
          },
        ]
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: const Text(
          "FAQ",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFFFAFAFA),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          // Header section

          // FAQ sections
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: faqData.length,
              itemBuilder: (context, sectionIndex) {
                final section = faqData[sectionIndex];
                final questions = section['questions'] as List<Map<String, String>>;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8E6CEF).withOpacity(0.06),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          section['category'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),

                      // Questions
                      ...questions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final question = entry.value;
                        final isLast = index == questions.length - 1;

                        return FAQItem(
                          question: question['question']!,
                          answer: question['answer']!,
                          isLast: isLast,
                        );
                      }).toList(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FAQItem extends StatefulWidget {
  final String question;
  final String answer;
  final bool isLast;

  const FAQItem({
    super.key,
    required this.question,
    required this.answer,
    this.isLast = false,
  });

  @override
  State<FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<FAQItem> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              isExpanded = !isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: const Color(0xFF8E6CEF),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),

        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: isExpanded ? null : 0,
          child: isExpanded
              ? Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E6CEF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.answer,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
              : const SizedBox.shrink(),
        ),

        if (!widget.isLast)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 1,
            color: Colors.grey[100],
          ),
      ],
    );
  }
}