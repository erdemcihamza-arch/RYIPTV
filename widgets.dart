import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';
import 'theme.dart';

class Poster extends StatelessWidget {
  final String? url;
  final IconData icon;
  final BoxFit fit;
  const Poster({
    super.key,
    this.url,
    this.icon = Icons.movie_outlined,
    this.fit = BoxFit.cover,
  });

  Widget _fallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A2145), Color(0xFF14141F)],
          ),
        ),
        child: Center(child: Icon(icon, color: Colors.white24, size: 36)),
      );

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || !u.startsWith('http')) return _fallback();
    return CachedNetworkImage(
      imageUrl: u,
      fit: fit,
      placeholder: (_, __) => _fallback(),
      errorWidget: (_, __, ___) => _fallback(),
    );
  }
}

class RatingBadge extends StatelessWidget {
  final String rating;
  const RatingBadge(this.rating, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xAA000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star_rounded, size: 13, color: AppColors.gold),
        const SizedBox(width: 2),
        Text(rating,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class PosterCard extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;
  const PosterCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(fit: StackFit.expand, children: [
                Poster(
                  url: item.logo,
                  icon: item.kind == Kind.series
                      ? Icons.video_library_outlined
                      : Icons.movie_outlined,
                ),
                if (item.rating != null)
                  Positioned(
                      top: 6, right: 6, child: RatingBadge(item.rating!)),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Text(text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      );
}

class PosterRow extends StatelessWidget {
  final String title;
  final List<Item> items;
  final void Function(Item) onTap;
  const PosterRow({
    super.key,
    required this.title,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title),
        SizedBox(
          height: 215,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => SizedBox(
              width: 220 * 0.6,
              child: PosterCard(item: items[i], onTap: () => onTap(items[i])),
            ),
          ),
        ),
      ],
    );
  }
}

class GroupChips extends StatelessWidget {
  final List<String> groups;
  final String? selected;
  final ValueChanged<String?> onSelect;
  const GroupChips({
    super.key,
    required this.groups,
    required this.selected,
    required this.onSelect,
  });

  Widget _chip(String label, String? value, bool locked) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: locked ? const Icon(Icons.lock, size: 15) : null,
          label: Text(label),
          selected: selected == value,
          onSelected: (_) => onSelect(value),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip('Tümü', null, false),
          for (final g in groups)
            _chip(g, g, Store.isLockedGroup(g) && !Store.isUnlocked),
        ],
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final ValueChanged<String> onChanged;
  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.icon = Icons.search,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: TextField(
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            hintText: hint,
            isDense: true,
          ),
        ),
      );
}

class GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const GradientButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: brandGradient,
          borderRadius: BorderRadius.circular(28),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Colors.white54)),
        ]),
      );
}
