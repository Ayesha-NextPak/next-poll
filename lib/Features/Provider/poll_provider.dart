// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import 'dart:io';
import 'dart:math' as math;
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:next_poll/Features/Services/connectivity_service.dart';
import 'package:next_poll/Features/helper/database_helper.dart';
import 'package:next_poll/Features/helper/prefs_helper.dart';

class PollProvider extends ChangeNotifier {
  final TextEditingController titleController = TextEditingController();
  final List<TextEditingController> optionNameControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController()
  ];
  final List<File?> optionImages = [null, null, null];
  final List<String?> existingImageUrls = [];
  GeoPoint? latlng;
  final ImagePicker _imagePicker = ImagePicker();
  bool isLoading = false;

  PollProvider() {
    startConnectivitySync();
  }

  void startConnectivitySync() {
    final service = ConnectivityService();
    service.internetStatusStream.listen((online) async {
      if (online) {
        await trySyncLocalPolls();
      }
    });
  }

  /// Pre-fills the create-poll form with AI-suggested text so the user only
  /// needs to add images and pick a location before submitting.
  void prePopulate({required String title, required List<String> options}) {
    titleController.text = title;

    // Ensure we always have exactly 3 controllers (create screen expects 3).
    while (optionNameControllers.length < 3) {
      optionNameControllers.add(TextEditingController());
    }
    for (int i = 0; i < 3; i++) {
      optionNameControllers[i].text = options[i];
    }

    // Reset images so the user picks fresh ones.
    for (int i = 0; i < optionImages.length; i++) {
      optionImages[i] = null;
    }
    latlng = null;

    notifyListeners();
  }

  void initializePoll(DocumentSnapshot poll) {
    final data = poll.data() as Map<String, dynamic>;
    titleController.text = data['title'];

    optionNameControllers.clear();
    optionImages.clear();
    existingImageUrls.clear();

    final options = List<Map<String, dynamic>>.from(data['options']);
    for (var option in options) {
      optionNameControllers.add(TextEditingController(text: option['name']));
      existingImageUrls.add(option['imageUrl'] ?? '');
      optionImages.add(null);
    }
  }

  Future<void> pickImage(int index) async {
    final pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      optionImages[index] = File(pickedFile.path);
      notifyListeners();
    }
  }

  Future<String?> uploadImage(File file, String pollId, int i) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('polls/$pollId/${i.toString()}_$pollId.jpg');
      final uploadTask = await storageRef.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      log("Error uploading image: $e");
      return null;
    }
  }

  Future<void> checkSubmissionPossible(
      String creatorId, BuildContext context) async {
    final isOnline = await ConnectivityService().checkNow();
    if (isOnline) {
      await submitPoll(creatorId, context);
      await SyncPrefs.setUnsyncedStatus(false);
    } else {
      if (!validateForm(context)) return;
      try {
        final optionNames = optionNameControllers.map((e) => e.text).toList();
        final optionFiles = optionImages;
        await DatabaseHelper().insertPollWithFiles(
            pollId: generateRandomId(),
            title: titleController.text,
            creatorId: creatorId,
            createdAt: DateTime.now(),
            optionNames: optionNames,
            optionFiles: optionFiles);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No internet. Poll saved locally')));
        await SyncPrefs.setUnsyncedStatus(true);
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save poll locally')));
      }
    }
  }

  Future<void> trySyncLocalPolls() async {
    final hasUnsynced = await SyncPrefs.hasUnsyncedPolls();
    final isOnline = await ConnectivityService().checkNow();

    if (hasUnsynced && isOnline) {
      final db = DatabaseHelper();
      final localPolls = await db.getAllPolls();

      for (var poll in localPolls) {
        final pollDoc = FirebaseFirestore.instance.collection('polls').doc();
        final pollId = pollDoc.id;
        final title = poll['title'];
        final creatorId = poll['creatorId'];
        final status = poll['status'];
        final totalVotes = poll['total_votes'];
        final options = await db.getOptionsForPoll(poll['id']);
        if (status == 'add') {
          final List<Map<String, dynamic>> firebaseOptions = [];
          for (int i = 0; i < options.length; i++) {
            final option = options[i];
            final name = option['name'];
            final imagePath = option['imageUrl'];
            final imageFile = File(imagePath);
            final imageUrl = await uploadImage(imageFile, pollId, i);
            firebaseOptions.add({
              'name': name,
              'imageUrl': imageUrl,
              'votes': option['votes'] ?? 0
            });
          }
          final createdAt =
              DateTime.fromMicrosecondsSinceEpoch(poll['createdAt']);
          await FirebaseFirestore.instance.collection('polls').doc(pollId).set({
            'pollId': pollId,
            'title': title,
            'creatorId': creatorId,
            'createdAt': createdAt,
            'total_votes': totalVotes,
            'options': firebaseOptions
          });
        } else if (status == 'update') {
          final List<Map<String, dynamic>> firebaseOptions = [];
          for (int i = 0; i < options.length; i++) {
            final option = options[i];
            final name = option['name'];
            final imagePath = option['imageUrl'];
            String? imageUrl;
            if (imagePath.startsWith('http')) {
              imageUrl = imagePath;
            } else {
              final imageFile = File(imagePath);
              imageUrl = await uploadImage(imageFile, pollId, i);
            }
            firebaseOptions.add({
              'name': name,
              'imageUrl': imageUrl,
              'votes': option['votes'] ?? 0
            });
          }
          await FirebaseFirestore.instance
              .collection('polls')
              .doc(poll['id'])
              .update({'title': title, 'options': firebaseOptions});
        } else if (status == 'delete') {
          DocumentSnapshot pollDoc = await FirebaseFirestore.instance
              .collection('polls')
              .doc(poll['id'])
              .get();
          if (pollDoc.exists) {
            List<dynamic> options = pollDoc['options'] ?? [];
            for (var option in options) {
              if (option['imageUrl'] != null) {
                String imageUrl = option['imageUrl'];
                String? filePath =
                    Uri.decodeFull(Uri.parse(imageUrl).pathSegments.lastWhere(
                          (element) => element.contains('polls'),
                          orElse: () => '',
                        ));
                if(filePath.isNotEmpty)
                {
                  await FirebaseStorage.instance.ref(filePath).delete();
                }
              }
            }
            await FirebaseFirestore.instance.collection('polls').doc(poll['id']).delete();

          }
        }
        for(var poll in localPolls)
        {
          await db.deletePoll(poll['id']);
        }
        await SyncPrefs.setUnsyncedStatus(false);
      }
    }
  }

  Future<void> submitPoll(String creatorId, BuildContext context) async {
    if (!validateForm(context)) return;

    isLoading = true;
    notifyListeners();

    try {
      final pollDoc = FirebaseFirestore.instance.collection('polls').doc();
      final pollId = pollDoc.id;

      final List<Map<String, dynamic>> options = [];
      for (int i = 0; i < 3; i++) {
        final imageUrl = await uploadImage(optionImages[i]!, pollId, i);
        if (imageUrl == null) throw Exception('Image upload failed');
        options.add({
          'name': optionNameControllers[i].text,
          'imageUrl': imageUrl,
          'votes': 0,
        });
      }

      await pollDoc.set({
        "pollId": pollId,
        'title': titleController.text,
        'position':latlng,
        'options': options,
        'createdAt': FieldValue.serverTimestamp(),
        'creatorId': creatorId,
        'total_votes': 0,
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poll created successfully!')));
      Navigator.pop(context);
    } catch (e) {
      log("Error submitting poll: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to create poll')));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePoll(BuildContext context, String pollId) async {
    isLoading = true;
    notifyListeners();
    final isOnline = await ConnectivityService().checkNow();
    try {
      final List<Map<String, dynamic>> updatedOptions = [];

      for (int i = 0; i < optionNameControllers.length; i++) {
        final String name = optionNameControllers[i].text;
        String? imageUrl = existingImageUrls[i];

        // Upload new image if selected
        if (optionImages[i] != null) {
          if (isOnline) {
            imageUrl = await uploadImage(optionImages[i]!, pollId, i);
          } else {
            imageUrl = optionImages[i]!.path;
          }
        }

        updatedOptions.add({
          'name': name,
          'imageUrl': imageUrl,
        });
      }

      if (isOnline) {
        await FirebaseFirestore.instance
            .collection('polls')
            .doc(pollId)
            .update({
          'title': titleController.text,
          'options': updatedOptions,
        });

        isLoading = false;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Poll updated successfully!')));
      } else {
        final db = DatabaseHelper();
        await db.updatePollWithOptions(
            pollId, titleController.text, updatedOptions);
        await SyncPrefs.setUnsyncedStatus(true);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Poll updated locally!')));
      }
      Navigator.pop(context);
      notifyListeners();
    } catch (e) {
      isLoading = false;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to create poll')));
      notifyListeners();
      rethrow; // Handle errors appropriately in the UI
    }
  }

  bool validateForm(BuildContext context) {
    if (titleController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Title is required')));
      return false;
    }
    if(latlng==null)
    {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Location is required')));
      return false;
    }
    for (int i = 0; i < optionNameControllers.length; i++) {
      if (optionNameControllers[i].text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Option ${i + 1} name is required')),
        );
        return false;
      }
    }
    if (optionImages.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image for all options')),
      );
      return false;
    }
    return true;
  }

  String generateRandomId([int length = 20]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rand = math.Random.secure();
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)])
        .join();
  }
}
