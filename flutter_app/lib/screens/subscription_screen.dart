import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/staggered_fade_in.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StaggeredFadeIn(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Upgrade to Pro', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              const Text(
                'Unlock AI-powered coaching, advanced analytics, and premium features.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              
              // Free Tier Card
              _SubscriptionCard(
                title: 'Free',
                price: '\$0/month',
                features: const [
                  'Basic workout logging',
                  'Exercise library access',
                  'Routine templates',
                  'Offline support',
                ],
                isHighlighted: false,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                },
              ),
              
              const SizedBox(height: 16),
              
              // Pro Tier Card
              _SubscriptionCard(
                title: 'Pro',
                price: '\$9.99/month',
                features: const [
                  'All Free features',
                  'AI form analysis',
                  'Progression insights',
                  'Plateau detection',
                  'Hardware integration (Apple Watch, Garmin)',
                  'Advanced analytics',
                  'Priority support',
                ],
                isHighlighted: true,
                onTap: () async {
                  HapticFeedback.heavyImpact();
                  await _showProDialog(context);
                },
              ),
              
              const SizedBox(height: 24),
              
              // Features Comparison
              _FeatureComparison(),
              
              const SizedBox(height: 24),
              
              // FAQ Section
              _FAQSection(),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showProDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Start 7-Day Free Trial'),
      content: const Text(
        'Try Pro features free for 7 days. No credit card required. Cancel anytime.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Maybe Later'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Free trial started! Enjoy Pro features.'),
              ),
            );
          },
          child: const Text('Start Trial'),
        ),
      ],
    ),
  );
}

class _SubscriptionCard extends StatelessWidget {
  final String title;
  final String price;
  final List<String> features;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _SubscriptionCard({
    required this.title,
    required this.price,
    required this.features,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isHighlighted
              ? const LinearGradient(
                  colors: [Color(0xFF6200EA), Color(0xFF3700B3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          border: isHighlighted
              ? null
              : Border.all(color: const Color(0x1EFFFFFF)),
          color: isHighlighted ? null : const Color(0x0DFFFFFF),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isHighlighted)
                  const Chip(
                    label: Text('POPULAR'),
                    backgroundColor: Color(0xFFCCFF00),
                    labelStyle: TextStyle(color: Colors.black),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              price,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isHighlighted ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 16),
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 20,
                      color: isHighlighted ? Colors.white : const Color(0xFFCCFF00),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(
                          color: isHighlighted ? const Color(0xE6FFFFFF) : const Color(0xB3FFFFFF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: isHighlighted ? Colors.white : null,
                foregroundColor: isHighlighted ? const Color(0xFF6200EA) : null,
              ),
              child: Text(isHighlighted ? 'Start Free Trial' : 'Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureComparison extends StatelessWidget {
  const _FeatureComparison();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Feature Comparison',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _ComparisonRow(
            feature: 'Workout Logging',
            free: true,
            pro: true,
          ),
          _ComparisonRow(
            feature: 'Exercise Library',
            free: true,
            pro: true,
          ),
          _ComparisonRow(
            feature: 'Routine Templates',
            free: true,
            pro: true,
          ),
          _ComparisonRow(
            feature: 'AI Form Analysis',
            free: false,
            pro: true,
          ),
          _ComparisonRow(
            feature: 'Progression Insights',
            free: false,
            pro: true,
          ),
          _ComparisonRow(
            feature: 'Hardware Integration',
            free: false,
            pro: true,
          ),
          _ComparisonRow(
            feature: 'Advanced Analytics',
            free: false,
            pro: true,
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String feature;
  final bool free;
  final bool pro;

  const _ComparisonRow({
    required this.feature,
    required this.free,
    required this.pro,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(feature),
          ),
          Expanded(
            child: Center(
              child: Icon(
                free ? Icons.check : Icons.close,
                color: free ? const Color(0xFFCCFF00) : Colors.white38,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(
                pro ? Icons.check : Icons.close,
                color: pro ? const Color(0xFF6200EA) : Colors.white38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FAQSection extends StatelessWidget {
  const _FAQSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frequently Asked Questions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _FAQItem(
            question: 'Can I cancel anytime?',
            answer: 'Yes, you can cancel your subscription at any time. You\'ll continue to have access until the end of your billing period.',
          ),
          _FAQItem(
            question: 'What happens after the trial?',
            answer: 'After your 7-day free trial, you\'ll be charged \$9.99/month unless you cancel. No credit card is required to start the trial.',
          ),
          _FAQItem(
            question: 'Is my data secure?',
            answer: 'Absolutely. All data is encrypted and stored securely. We never share your personal information with third parties.',
          ),
          _FAQItem(
            question: 'Can I use on multiple devices?',
            answer: 'Yes! Your account syncs across all your devices, so you can track workouts on your phone, tablet, or computer.',
          ),
        ],
      ),
    );
  }
}

class _FAQItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FAQItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(question),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(answer),
        ),
      ],
    );
  }
}
