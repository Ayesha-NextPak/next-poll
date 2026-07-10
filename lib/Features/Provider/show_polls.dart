// ignore_for_file: unnecessary_null_comparison, use_build_context_synchronously

import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:next_poll/Features/Services/connectivity_service.dart';
import 'package:next_poll/Features/helper/database_helper.dart';
import 'package:next_poll/Features/helper/prefs_helper.dart';

class ShowPolls {
  static void deletePoll(String pollId, BuildContext context) async {
    try {
      final isOnline = await ConnectivityService().checkNow();

      if (isOnline) {
        DocumentSnapshot pollDoc = await FirebaseFirestore.instance
            .collection('polls')
            .doc(pollId)
            .get();

        if (pollDoc.exists) {
          List<dynamic> options = pollDoc['options'] ?? [];
          for (var option in options) {
            if (option['imageUrl'] != null) {
              String imageUrl = option['imageUrl'];

              String? filePath = Uri.decodeFull(Uri.parse(imageUrl)
                  .pathSegments
                  .lastWhere((segment) => segment.contains('polls'),
                      orElse: () => ''));

              if (filePath != null && filePath.isNotEmpty) {
                await FirebaseStorage.instance.ref(filePath).delete();
              }
            }
          }
        }

        await FirebaseFirestore.instance
            .collection('polls')
            .doc(pollId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Poll and associated images deleted successfully')),
        );
      }else
      {
        final db = DatabaseHelper();
        await db.insertPollForDeletion(pollId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No Internet. Poll will be deleted when you come back online.')),
        );
        await SyncPrefs.setUnsyncedStatus(true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting poll: $e')),
      );
    }
  }

  static Future<void> handleVote(String pollId, int optionIndex,
      BuildContext context, String currentUserId) async {
    try {
      final pollDoc =
          FirebaseFirestore.instance.collection('polls').doc(pollId);
      final pollSnapshot = await pollDoc.get();

      if (pollSnapshot.exists) {
        final data = pollSnapshot.data() as Map<String, dynamic>;
        final totalvotes = data['total_votes'];
        final options = data['options'] as List<dynamic>;

        // Check if the user has already voted
        for (var option in options) {
          if (option['voters'] != null &&
              (option['voters'] as List).contains(currentUserId)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You have already voted.')),
            );
            return;
          }
        }

        // Update the selected option's voters
        final voters = options[optionIndex]['voters'] ?? [];
        voters.add(currentUserId);

        options[optionIndex]['voters'] = voters;
        options[optionIndex]['votes'] =
            (options[optionIndex]['votes'] ?? 0) + 1;

        await pollDoc.update({'options': options});

        await pollDoc.update({'total_votes': totalvotes + 1});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vote submitted successfully!')),
        );
      }
    } catch (e) {
      log('Error voting: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit vote.')),
      );
    }
  }
}
