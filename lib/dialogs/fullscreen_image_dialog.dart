import 'dart:io';

import 'package:flutter/material.dart';

import 'package:helloworld/settings.dart';

class FullscreenImageDialog extends StatelessWidget {
  final File imageFile;

  const FullscreenImageDialog({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(0),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(color: Colors.black),
          child: image(imageFile),
        ),
      ),
    );
  }

  Image image(File file) {
    if (IS_WEB_BUILD) {
      return Image.network(
        'https://img.freepik.com/fotos-kostenlos/niedlicher-welpe-des-cavalier-king-charles-spaniel-der-auf-einem-baumstamm-liegt_384344-5181.jpg?w=1060&t=st=1715877344~exp=1715877944~hmac=f2ca9e7ee7c13437d99f5d68a49c8a0cf072c94a45b647b2ab0fca8094454bba',
        fit: BoxFit.contain,
      );
    } else {
      return Image.file(
        file,
        fit: BoxFit.contain,
      );
    }
  }
}
