import 'dart:io';

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

import 'package:helloworld/settings.dart';

class PictureCarousel extends StatelessWidget {
  final List<File> pics;
  final Function(File) onPicRemove;

  const PictureCarousel({
    super.key,
    required this.pics,
    required this.onPicRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (pics.isEmpty) {
      return const Center(child: Text("No Picture added."));
    }

    return CarouselSlider(
      options: CarouselOptions(
        autoPlay: true,
        aspectRatio: 2.0,
        enlargeCenterPage: true,
      ),
      items: pics.map((file) {
        return Container(
          margin: const EdgeInsets.all(5.0),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(5.0)),
            child: Stack(
              alignment: AlignmentDirectional.bottomEnd,
              children: [
                image(file),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => onPicRemove(file),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Image image(File file) {
    if (IS_WEB_BUILD) {
      return Image.network(
        'https://m.media-amazon.com/images/I/41t0VHvBEwL.jpg',
        fit: BoxFit.cover,
        width: 1000,
      );
    } else {
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: 1000,
      );
    }
  }
}
