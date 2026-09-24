import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/user_profile_page.dart';
import '../pages/gig_full_detail_page.dart';
import '../pages/casting_full_detail_page.dart';
import '../ui/board_theme.dart';
import 'board_widgets.dart';

/// Cards shared by the Network rails and their full directories, so a
/// person looks the same whether you met them in a swipe or in a grid.

/// A person as a comp-card crop — the shape you judge talent in — with a
/// single ink stud to follow.
///
/// An ink square on the photo rather than a chip under the name: with one
/// accent in the palette that chip would have to be brass, which spends
/// the money colour on a social action.
class PersonCropCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final double? width;
  final double cropHeight;
  final bool dark;
  final bool requested;
  final bool enabled;
  final VoidCallback onFollow;

  const PersonCropCard({
    super.key,
    required this.doc,
    required this.cropHeight,
    required this.dark,
    required this.requested,
    required this.enabled,
    required this.onFollow,
    this.width,
  });

  /// Room for the name and meta beneath a crop. Measured from the scaler
  /// rather than hardcoded, so bumping the system font grows the card
  /// instead of clipping the city off the bottom.
  static double captionHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return 8 + scaler.scale(17) * 1.05 + 3 + scaler.scale(9.5) * 1.1 + 4;
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final name =
        (data['fullName'] ??
                '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}')
            .toString()
            .trim();
    final location = (data['location'] ?? '').toString();
    final height = (data['height'] ?? '').toString();

    // City first, then height — the two things that decide whether a
    // stranger is worth a tap.
    final meta = [
      if (location.isNotEmpty) location,
      if (height.isNotEmpty)
        '$height ${(data['heightUnit'] ?? 'cm').toString()}',
    ].join(' · ');

    final card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserProfilePage(uid: doc.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: cropHeight,
            child: BoardMedia(
              url: (data['profileImage'] ?? '').toString(),
              dark: dark,
              cut: 20,
              overlay: Align(
                alignment: Alignment.bottomLeft,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: (requested || !enabled) ? null : onFollow,
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    color: BoardColors.ink,
                    child: Icon(
                      requested ? Icons.check : Icons.add,
                      size: 15,
                      color: requested ? BoardColors.brass : BoardColors.onInk,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              (name.isEmpty ? 'User' : name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BoardType.title(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BoardType.mono(
                fontSize: 9.5,
                fontWeight: FontWeight.w400,
                color: BoardColors.inkSoft,
              ),
            ),
          ],
        ],
      ),
    );

    return width == null ? card : SizedBox(width: width, child: card);
  }
}

/// ---------------------------------------------------------------------
/// Posters
/// ---------------------------------------------------------------------

/// A brand or agency with live postings, folded together from the
/// postings themselves.
class BoardPoster {
  final String name;
  final bool isGig;

  /// Postings currently taking applications.
  int openCount;

  /// Everything they have ever posted. A brand with nothing open is
  /// still on the board, and still worth seeing.
  int postingCount;

  QueryDocumentSnapshot newest;
  Map<String, dynamic> newestData;

  BoardPoster({
    required this.name,
    required this.isGig,
    required this.openCount,
    required this.postingCount,
    required this.newest,
    required this.newestData,
  });

  /// Folds gigs and castings into one list of the brands and agencies on
  /// the board.
  ///
  /// `brands/` and `agency/` are owner-only under the current rules, so a
  /// poster is only visible through what they have posted. Filtering to
  /// open postings would hide every brand between campaigns — so this
  /// takes all of them and reports how many calls are currently open.
  static List<BoardPoster> collect({
    required List<QueryDocumentSnapshot> gigs,
    required List<QueryDocumentSnapshot> castings,
  }) {
    final posters = <String, BoardPoster>{};

    void add(QueryDocumentSnapshot doc, bool isGig) {
      final data = doc.data() as Map<String, dynamic>? ?? {};

      // Firestore hands back nulls for fields a form never filled, and
      // `null.toString()` is the string "null" — which reads as a real
      // name to everything downstream. Normalise once, here.
      String pick(List<String> keys) {
        for (final key in keys) {
          final value = (data[key] ?? '').toString().trim();
          if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
        }
        return '';
      }

      final name = isGig
          ? pick(['brandName'])
          : pick(['agencyName', 'agency', 'posterName']);

      // A posting whose poster never set a display name still belongs on
      // the board. Fall back to the work itself, and key on the owner so
      // two unnamed posters don't collapse into one card.
      final ownerId = pick(isGig ? ['brandId'] : ['agencyId']);
      final label = name.isNotEmpty ? name : pick(['projectTitle', 'title']);
      if (label.isEmpty) return;

      final isOpen = pick(['status']).toLowerCase() == 'open';

      final key = name.isNotEmpty
          ? 'name:${name.toLowerCase()}'
          : (ownerId.isNotEmpty ? 'owner:$ownerId' : 'doc:${doc.id}');

      final existing = posters[key];
      if (existing == null) {
        posters[key] = BoardPoster(
          name: label,
          isGig: isGig,
          openCount: isOpen ? 1 : 0,
          postingCount: 1,
          newest: doc,
          newestData: data,
        );
      } else {
        existing.postingCount++;
        // Tapping a poster should land on something applicable, so an
        // open call outranks whatever was seen first.
        if (isOpen && existing.openCount == 0) {
          existing.newest = doc;
          existing.newestData = data;
        }
        if (isOpen) existing.openCount++;
      }
    }

    for (final d in gigs) {
      add(d, true);
    }
    for (final d in castings) {
      add(d, false);
    }

    // Hiring now, then most active, then alphabetical so the order is
    // stable between snapshots.
    return posters.values.toList()..sort((a, b) {
      final byOpen = b.openCount.compareTo(a.openCount);
      if (byOpen != 0) return byOpen;
      final byPostings = b.postingCount.compareTo(a.postingCount);
      if (byPostings != 0) return byPostings;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }
}

/// No photograph, because a brand's imagery isn't reachable from a model
/// account — so the card leans on the mark and the one number that
/// matters, and the absence of a crop is what tells it apart from the
/// people rails.
class PosterCard extends StatelessWidget {
  final BoardPoster poster;

  /// Null stretches the card to its parent — correct in the directory's
  /// vertical list, fatal in a horizontal rail where the parent offers
  /// unbounded width. Rails pass [railWidth].
  final double? width;

  /// The width a card takes in a horizontal rail.
  static const railWidth = 172.0;

  const PosterCard({super.key, required this.poster, this.width});

  static const _pad = 13.0;
  static const _mark = 26.0;
  static const _nameSize = 20.0;
  static const _nameLines = 2;
  static const _openSize = 10.0;

  /// The card's height, summed from the parts it actually draws rather
  /// than estimated — a brand name runs to two lines, and being even
  /// 1.5px short is still a yellow overflow stripe across the rail.
  static double heightFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return _pad * 2 +
        _mark +
        10 +
        scaler.scale(_nameSize) * 0.95 * _nameLines +
        8 +
        scaler.scale(_openSize) * 1.1 +
        2;
  }

  @override
  Widget build(BuildContext context) {
    // Defensive: `collect` guarantees a non-empty name today, but a
    // RangeError here would take out the whole rail rather than one card.
    final trimmed = poster.name.trim();
    final initial = trimmed.isEmpty ? '·' : trimmed[0].toUpperCase();

    final card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => poster.isGig
              ? GigFullDetailPage(
                  gigId: poster.newest.id,
                  data: poster.newestData,
                  brandName: poster.name,
                )
              : CastingFullDetailPage(
                  castingId: poster.newest.id,
                  data: poster.newestData,
                  posterName: poster.name,
                ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(_pad),
        decoration: BoxDecoration(
          color: BoardColors.slate,
          borderRadius: BorderRadius.circular(BoardRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: _mark,
                  height: _mark,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: BoardColors.brass,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    initial,
                    style: BoardType.mono(fontSize: 11, color: BoardColors.ink),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    poster.isGig ? 'Brand' : 'Agency',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BoardType.mono(
                      fontSize: 9,
                      color: BoardColors.onInkSoft,
                      letterSpacing: 0.95,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: Text(
                (trimmed.isEmpty ? 'Unnamed' : trimmed),
                maxLines: _nameLines,
                overflow: TextOverflow.ellipsis,
                style: BoardType.display(
                  fontSize: _nameSize,
                  color: BoardColors.onInk,
                  height: 0.95,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              poster.openCount > 0
                  ? '${poster.openCount} OPEN CALL${poster.openCount == 1 ? '' : 'S'}'
                  : 'NO OPEN CALLS',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // Brass on slate has to be the tint, or the two share a
              // lightness band and the line sinks into the panel. A brand
              // with nothing open drops to the muted voice rather than
              // wearing the accent for a number that is zero.
              style: BoardType.mono(
                fontSize: _openSize,
                color: poster.openCount > 0
                    ? BoardColors.brassText
                    : BoardColors.onInkSoft,
              ),
            ),
          ],
        ),
      ),
    );

    return width == null ? card : SizedBox(width: width, child: card);
  }
}
