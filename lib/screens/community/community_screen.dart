import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/theme.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: const Text('Community'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Join the Community',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect with top traders and learn from the best',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.gray,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Social Links
            const Text(
              'Follow Us',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildSocialCard(
              'Twitter',
              '@pumpfunds',
              'Follow us for updates and alpha calls',
              Icons.close, // Using X (close) as Twitter icon
              'https://twitter.com/pumpfunds',
            ),
            const SizedBox(height: 12),
            _buildSocialCard(
              'Discord',
              'Join our server',
              'Chat with traders and get real-time alerts',
              Icons.discord,
              'https://discord.gg/pumpfunds',
            ),
            const SizedBox(height: 12),
            _buildSocialCard(
              'Telegram',
              '@pumpfunds_official',
              'Get instant notifications and support',
              Icons.send,
              'https://t.me/pumpfunds',
            ),
            
            const SizedBox(height: 32),
            
            // Top Traders
            const Text(
              'Featured Traders',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildTraderCard(
              'CryptoWhale',
              '@cryptowhale',
              'Professional trader with 5+ years experience',
              '+142% ROI',
              'https://twitter.com/cryptowhale',
            ),
            const SizedBox(height: 12),
            _buildTraderCard(
              'SolanaKing',
              '@solanaking',
              'Early mover in Solana ecosystem',
              '+98% ROI',
              'https://twitter.com/solanaking',
            ),
            const SizedBox(height: 12),
            _buildTraderCard(
              'DeFiMaster',
              '@defimaster',
              'DeFi specialist and yield farmer',
              '+76% ROI',
              'https://twitter.com/defimaster',
            ),
            
            const SizedBox(height: 32),
            
            // Testimonials
            const Text(
              'What Traders Say',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildTestimonialCard(
              'Alex M.',
              'Copy-trading made easy! I\'ve been following top wallets and seeing consistent gains.',
              4.5,
            ),
            const SizedBox(height: 12),
            _buildTestimonialCard(
              'Sarah K.',
              'The best way to learn from successful traders. Auto-copy feature is a game changer.',
              5.0,
            ),
            const SizedBox(height: 12),
            _buildTestimonialCard(
              'Mike R.',
              'Finally, a platform that lets me invest alongside the pros. Highly recommend!',
              4.8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialCard(String platform, String handle, String description, IconData icon, String url) {
    return GestureDetector(
      onTap: () => _launchUrl(url),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border, width: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Icon(icon, color: AppColors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    platform,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    handle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.gray,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.gray,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppColors.gray, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildTraderCard(String name, String handle, String bio, String roi, String url) {
    return GestureDetector(
      onTap: () => _launchUrl(url),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border, width: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Center(
                child: Icon(Icons.person_outline, color: AppColors.white, size: 24),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: AppColors.white, size: 14),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    handle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.gray,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    bio,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.gray,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              roi,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestimonialCard(String name, String testimonial, double rating) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border, width: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Center(
                  child: Icon(Icons.person_outline, color: AppColors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < rating.floor() ? Icons.star : Icons.star_border,
                          color: AppColors.white,
                          size: 12,
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"$testimonial"',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.gray,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
