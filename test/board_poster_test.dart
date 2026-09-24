import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_modelx/widgets/network_cards.dart';

/// A stand-in for a Firestore document. Only the two members
/// [BoardPoster.collect] touches are implemented; everything else throws
/// loudly if the fold ever starts reaching for more.
class _FakeDoc implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> _data;

  _FakeDoc(this.id, this._data);

  @override
  Map<String, dynamic> data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

void main() {
  group('BoardPoster.collect', () {
    test('folds gigs and castings into one list', () {
      final posters = BoardPoster.collect(
        gigs: [
          _FakeDoc('g1', {
            'brandName': 'Raw Mango',
            'brandId': 'b1',
            'status': 'open',
          }),
          _FakeDoc('g2', {
            'brandName': 'raw mango',
            'brandId': 'b1',
            'status': 'open',
          }),
        ],
        castings: [
          _FakeDoc('c1', {
            'agencyName': 'ModelX',
            'agencyId': 'a1',
            'status': 'open',
          }),
        ],
      );

      expect(posters.length, 2);
      // Ranked by how much they're hiring.
      expect(posters.first.name, 'Raw Mango');
      expect(posters.first.openCount, 2);
      expect(posters.first.isGig, isTrue);
      expect(posters.last.isGig, isFalse);
    });

    test('a brand with nothing open is still on the board', () {
      // The board is the brands on it. Filtering to open postings hid
      // every brand between campaigns — and `brands/` is owner-only, so a
      // posting is the only way a brand is visible at all.
      final posters = BoardPoster.collect(
        gigs: [
          _FakeDoc('g1', {
            'brandName': 'Bhane',
            'brandId': 'b1',
            'status': 'draft',
          }),
          _FakeDoc('g2', {
            'brandName': 'Bhane',
            'brandId': 'b1',
            'status': 'closed',
          }),
        ],
        castings: const [],
      );

      expect(posters.single.name, 'Bhane');
      expect(posters.single.openCount, 0);
      expect(posters.single.postingCount, 2);
    });

    test('brands hiring now sort above brands that are not', () {
      final posters = BoardPoster.collect(
        gigs: [
          _FakeDoc('g1', {
            'brandName': 'Quiet',
            'brandId': 'b1',
            'status': 'draft',
          }),
          _FakeDoc('g2', {
            'brandName': 'Hiring',
            'brandId': 'b2',
            'status': 'open',
          }),
        ],
        castings: const [],
      );
      expect(posters.first.name, 'Hiring');
      expect(posters.last.name, 'Quiet');
    });

    test('tapping a poster lands on an open call when they have one', () {
      final posters = BoardPoster.collect(
        gigs: [
          _FakeDoc('g1', {
            'brandName': 'Bhane',
            'brandId': 'b1',
            'status': 'closed',
          }),
          _FakeDoc('g2', {
            'brandName': 'Bhane',
            'brandId': 'b1',
            'status': 'open',
          }),
        ],
        castings: const [],
      );
      expect(posters.single.newest.id, 'g2');
    });

    test('a gig with no brandName still appears', () {
      // The regression: `data['brandName']` was left unguarded by the
      // `?? ''`, so a missing name became the string "null" — and any
      // empty name was dropped from the board entirely.
      final posters = BoardPoster.collect(
        gigs: [
          _FakeDoc('g1', {'brandId': 'b1', 'projectTitle': 'Spring Campaign'}),
        ],
        castings: const [],
      );

      expect(posters.length, 1);
      expect(posters.single.name, 'Spring Campaign');
      expect(posters.single.name, isNot('null'));
    });

    test('an explicit null name never becomes the word "null"', () {
      final posters = BoardPoster.collect(
        gigs: [
          _FakeDoc('g1', {
            'brandName': null,
            'brandId': 'b1',
            'projectTitle': 'Denim Drop',
          }),
        ],
        castings: const [],
      );
      expect(posters.single.name, 'Denim Drop');
    });

    test('two unnamed brands do not collapse into one card', () {
      final posters = BoardPoster.collect(
        gigs: [
          _FakeDoc('g1', {'brandId': 'b1', 'projectTitle': 'Spring'}),
          _FakeDoc('g2', {'brandId': 'b2', 'projectTitle': 'Resort'}),
        ],
        castings: const [],
      );
      expect(posters.length, 2);
    });

    test('castings still read their several name fields', () {
      for (final key in ['agencyName', 'agency', 'posterName']) {
        final posters = BoardPoster.collect(
          gigs: const [],
          castings: [
            _FakeDoc('c1', {key: 'ModelX'}),
          ],
        );
        expect(posters.single.name, 'ModelX', reason: 'via $key');
      }
    });

    test('a posting with nothing to show is skipped, not rendered blank', () {
      final posters = BoardPoster.collect(
        gigs: [
          _FakeDoc('g1', {'brandId': 'b1'}),
        ],
        castings: const [],
      );
      expect(posters, isEmpty);
    });
  });
}
