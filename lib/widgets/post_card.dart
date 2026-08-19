import 'package:flutter/material.dart';
import '../ui/app_theme.dart';
import 'app_card.dart';

/// A generic post/announcement card — a real, parameterized, shared
/// component replacing the old `agency/widgets/post_card.dart` stub,
/// which hardcoded identical "Post title" / "Post content preview
/// goes here..." text with no data binding at all. This widget takes
/// the same content as constructor props (defaulting to the exact
/// values the old stub always rendered, so existing call sites are
/// visually unchanged) so any future real data source can bind to it
/// without another rewrite.
class PostCard extends StatelessWidget {
  final String title;
  final String content;
  final int likeCount;
  final String timeAgo;

  const PostCard({
    super.key,
    this.title = 'Post title',
    this.content = 'Post content preview goes here...',
    this.likeCount = 12,
    this.timeAgo = '2h',
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.bodyEmphasized.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Text(content, style: AppTypography.body.copyWith(color: AppColors.inkSoft)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.thumb_up_alt_outlined, size: AppIconSize.sm, color: AppColors.inkFaint),
                  const SizedBox(width: 8),
                  Text('$likeCount', style: AppTypography.metadata),
                ],
              ),
              Text(timeAgo, style: AppTypography.metadata),
            ],
          ),
        ],
      ),
    );
  }
}
