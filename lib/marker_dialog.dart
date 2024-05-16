import 'dart:io';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';

import 'package:helloworld/picture_carousel.dart';
import 'package:helloworld/data/marker_data.dart';

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
  late TextEditingController descriptionController;
  late TextEditingController dateController;

  @override
  void initState() {
    super.initState();
    descriptionController =
        TextEditingController(text: widget.markerData.description);
    dateController =
        TextEditingController(text: widget.markerData.dateOfVisit.toString());
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  void changeDate(DateTime value) {
    setState(() {
      widget.markerData.dateOfVisit = value;
    });
    widget.onUpdate(widget.markerData);
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
          TextField(
              controller: dateController, //editing controller of this TextField
              decoration: const InputDecoration(
                icon: Icon(Icons.calendar_today), //icon of text field
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
                    lastDate: DateTime(2101));
                if (pickedDate != null) {
                  changeDate(pickedDate);
                }
              }),

          if (widget.markerData.type != 2)
            TextField(
              maxLines: null,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Description',
                hintStyle: TextStyle(color: Colors.grey),
              ),
              controller: descriptionController,
              onChanged: (text) => changeDescription(text),
            ),
          if (widget.markerData.type != 2)
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
