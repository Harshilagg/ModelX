import 'package:flutter/material.dart';
import '../scouting/search_service.dart';

class SearchBar extends StatefulWidget {
  const SearchBar({super.key});

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctl,
              decoration: const InputDecoration(border: InputBorder.none, hintText: 'Search models, castings, talent...'),
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                SearchService.setQuery(v.trim());
              },
            ),
          ),
          IconButton(onPressed: () { _ctl.clear(); SearchService.setQuery(''); }, icon: const Icon(Icons.clear, size: 18)),
        ],
      ),
    );
  }
}

