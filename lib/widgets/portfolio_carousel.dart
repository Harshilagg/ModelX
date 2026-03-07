import 'package:flutter/material.dart';

class PortfolioCarousel extends StatefulWidget {
  final List<String> images;

  const PortfolioCarousel({
    super.key,
    required this.images,
  });

  @override
  State<PortfolioCarousel> createState() =>
      _PortfolioCarouselState();
}

class _PortfolioCarouselState
    extends State<PortfolioCarousel> {

  late PageController _controller;
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.image),
      );
    }

    return Stack(
      children: [

        // IMAGE VIEW
        PageView.builder(
          controller: _controller,
          physics: const PageScrollPhysics(),
          itemCount: widget.images.length,
          onPageChanged: (index) {
            setState(() => currentPage = index);
          },
          itemBuilder: (_, i) {
            return SizedBox.expand(
              child: Image.network(
                widget.images[i],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: Colors.grey.shade300),
              ),
            );

          },
        ),

        // DOT INDICATOR
        Positioned(
          bottom: 6,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.images.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin:
                    const EdgeInsets.symmetric(horizontal: 2),
                width: currentPage == index ? 10 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: currentPage == index
                      ? Colors.white
                      : Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
