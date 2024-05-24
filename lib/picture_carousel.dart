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
      return Text("No Picture added.");
    }

    final List<Widget> imageSliders = pics
        .map((item) => Container(
              child: Container(
                margin: EdgeInsets.all(5.0),
                child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(5.0)),
                    child: Stack(
                      alignment: AlignmentDirectional.bottomEnd,
                      children: <Widget>[
                        image(item),
                        Positioned(
                          bottom: 0.0,
                          left: 0.0,
                          right: 0.0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color.fromARGB(200, 0, 0, 0),
                                  Color.fromARGB(0, 0, 0, 0)
                                ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                            ),
                            padding: EdgeInsets.symmetric(
                                vertical: 10.0, horizontal: 20.0),
                          ),
                        ),
                        IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => onPicRemove(item)),
                      ],
                    )),
              ),
            ))
        .toList();

    return CarouselSlider(
      options: CarouselOptions(
        aspectRatio: 2.0,
        enlargeCenterPage: true,
        autoPlay: true,
      ),
      items: imageSliders,
    );
  }

  Image image(File file) {
    if (IS_WEB_BUILD) {
      return Image.network(
        'https://img.freepik.com/fotos-kostenlos/niedlicher-welpe-des-cavalier-king-charles-spaniel-der-auf-einem-baumstamm-liegt_384344-5181.jpg?w=1060&t=st=1715877344~exp=1715877944~hmac=f2ca9e7ee7c13437d99f5d68a49c8a0cf072c94a45b647b2ab0fca8094454bba',
        fit: BoxFit.cover,
        width: 1000,
        //MediaQuery.of(context).size.width,
      );
    } else {
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: 1000,
        //MediaQuery.of(context).size.height,
      );
    }
  }
}
