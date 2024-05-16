import 'dart:io';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';

import 'package:helloworld/picture_carousel.dart';
import 'package:helloworld/data/marker.dart';

class MarkerDialog extends StatefulWidget {
  final LatLng position;
  final Marker marker;
  final Function(Marker) onUpdate;
  final Function onDelete;
  final Function onSelectAfter;

  const MarkerDialog({
    super.key,
    required this.position,
    required this.marker,
    required this.onUpdate,
    required this.onDelete,
    required this.onSelectAfter,
  });

  @override
  _MarkerDialogState createState() => _MarkerDialogState();
}

class _MarkerDialogState extends State<MarkerDialog> {
  late TextEditingController descriptionController;
  late TextEditingController dateController;

  @override
  void initState() {
    super.initState();
    descriptionController =
        TextEditingController(text: widget.marker.description);
    dateController = TextEditingController(
        text: widget.marker.dateOfVisit.toString().split(' ')[0]);
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  void changeDate(DateTime value) {
    setState(() {
      widget.marker.dateOfVisit = value;
      dateController.text = widget.marker.dateOfVisit.toString().split(' ')[0];
    });
    widget.onUpdate(widget.marker);
  }

  void changeName(String value) {
    setState(() {
      widget.marker.name = value;
    });
    widget.onUpdate(widget.marker);
  }

  void changeDescription(String text) {
    setState(() {
      widget.marker.description = text;
    });
    widget.onUpdate(widget.marker);
  }

  void removePicture(File file) {
    setState(() {
      widget.marker.pics.remove(file);
    });
    widget.onUpdate(widget.marker);
  }

  void changeType() {
    setState(() {
      widget.marker.type =
          (widget.marker.type + 1) % ASSET_FILES_FOR_TYPES.length;
    });
    widget.onUpdate(widget.marker);
  }

  Future<void> pickImages() async {
    final List<XFile> selectedImages = await ImagePicker().pickMultiImage();
    setState(() {
      widget.marker.pics.addAll(selectedImages.map((e) => File(e.path)));
    });
    widget.onUpdate(widget.marker);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: TextField(
        decoration: InputDecoration(
            border: InputBorder.none,
            labelText:
                widget.marker.type == 2 ? 'Stopover' : widget.marker.name,
            enabled: widget.marker.type != 2,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold)),
        onChanged: (value) => changeName(value),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.marker.type != 2)
            TextField(
              maxLines: 4,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Description',
                hintStyle: TextStyle(color: Colors.grey),
              ),
              controller: descriptionController,
              onChanged: (text) => changeDescription(text),
            ),

          const Spacer(), // <-- Set height
          if (widget.marker.type != 2)
            PictureCarousel(
              pics: widget.marker.pics,
              onPicRemove: (file) => removePicture(file),
            ),
          const Spacer(),
          TextField(
              controller: dateController, //editing controller of this TextField
              decoration: const InputDecoration(
                icon: Icon(Icons.calendar_today), //icon of text field
                border: InputBorder.none,
                hintText: "Enter Date", //label text of field
                hintStyle: TextStyle(color: Colors.grey),
              ),
              readOnly: true, // when true user cannot edit text
              onTap: () async {
                //when click we have to show the datepicker
                DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(), //get today's date
                    firstDate: DateTime(
                        2000), //DateTime.now() - not to allow to choose before today.
                    lastDate: DateTime.now());
                if (pickedDate != null) {
                  changeDate(pickedDate);
                }
              }),
          const SizedBox(
            height: 10,
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
            widget.marker.assetFileForType,
            width: 30,
            height: 30,
          ),
        ),
        IconButton(
          icon: Image.asset('assets/pics.png', width: 30, height: 30),
          onPressed: () => pickImages(),
        ),
        IconButton(
          icon: Image.asset('assets/bin.png', width: 30, height: 30),
          onPressed: () => widget.onDelete(),
        ),
        IconButton(
          // Insert after button. Once pressed, then the next markers will be inserted after this marker in the route
          icon: Image.asset(
            'assets/insert_after.png',
            width: 30,
            height: 30,
          ),
          onPressed: () => widget.onSelectAfter(),
        ),
      ],
    );
  }
}
