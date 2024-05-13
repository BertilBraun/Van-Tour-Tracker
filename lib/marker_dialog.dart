import 'dart:io';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';

import 'package:helloworld/picture_carousel.dart';
import 'package:helloworld/marker_data.dart';

class MarkerDialog extends StatefulWidget {
  final LatLng position;
  final MarkerData markerData;
  final Function(MarkerData) onUpdate;
  final Function onDelete;
  final Function onSelectAfter;

  const MarkerDialog({
    super.key,
    required this.position,
    required this.markerData,
    required this.onUpdate,
    required this.onDelete,
    required this.onSelectAfter,
  });

  @override
  _MarkerDialogState createState() => _MarkerDialogState();
}

class _MarkerDialogState extends State<MarkerDialog> {
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.markerData.description);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void changeName(String value) {
    setState(() {
      widget.markerData.name = value;
    });
    widget.onUpdate(widget.markerData);
  }

  void changeDescription(String text) {
    setState(() {
      widget.markerData.description = text;
    });
    widget.onUpdate(widget.markerData);
  }

  void removePicture(File file) {
    setState(() {
      widget.markerData.pics.remove(file);
    });
    widget.onUpdate(widget.markerData);
  }

  void changeType() {
    setState(() {
      widget.markerData.type =
          (widget.markerData.type + 1) % ASSET_FILES_FOR_TYPES.length;
    });
    widget.onUpdate(widget.markerData);
  }

  Future<void> pickImages() async {
    final List<XFile> selectedImages = await ImagePicker().pickMultiImage();
    setState(() {
      widget.markerData.pics.addAll(selectedImages.map((e) => File(e.path)));
    });
    widget.onUpdate(widget.markerData);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: TextField(
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText:
              widget.markerData.type == 2 ? 'Stopover' : widget.markerData.name,
          enabled: widget.markerData.type != 2,
        ),
        onChanged: (value) => changeName(value),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.markerData.type != 2)
            TextField(
              maxLines: null,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Description',
                hintStyle: TextStyle(color: Colors.grey),
              ),
              controller: _descriptionController,
              onChanged: (text) => changeDescription(text),
            ),
          PictureCarousel(
            pics: widget.markerData.pics,
            onPicRemove: (file) => removePicture(file),
          ),
          Text(
              'Loc: (${widget.position.latitude.toStringAsFixed(2)}, ${widget.position.longitude.toStringAsFixed(2)})'),
          // TODO display dateOfVisit (with a selector for the correct date when clicked)
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => changeType(),
          icon: Image.asset(
            widget.markerData.assetFileForType,
            width: 40,
            height: 40,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_to_photos),
          onPressed: () => pickImages(),
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => widget.onDelete(),
        ),
        IconButton(
          // Insert after button. Once pressed, then the next markers will be inserted after this marker in the route
          icon: const Icon(Icons.arrow_right_rounded),
          onPressed: () => widget.onSelectAfter(),
        ),
      ],
    );
  }
}
