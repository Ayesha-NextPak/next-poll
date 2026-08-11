// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, unnecessary_null_comparison

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:next_poll/Features/AuthScreen/auth_services.dart';
import 'package:next_poll/Features/ChatScreens/chat_screen.dart';
import 'package:next_poll/Features/ChatScreens/conversations_screen.dart';
import 'package:next_poll/Features/HomeScreens/create_poll_screen.dart';
import 'package:next_poll/Features/HomeScreens/edit_poll_screen.dart';
import 'package:next_poll/Features/Provider/chat_provider.dart';
import 'package:next_poll/Features/Provider/poll_provider.dart';
import 'package:next_poll/Features/Provider/show_polls.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:page_transition/page_transition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class PollScreen extends StatefulWidget {
  const PollScreen({super.key});

  @override
  _PollScreenState createState() => _PollScreenState();
}

class _PollScreenState extends State<PollScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PollProvider>();
      provider.loadAd(context, MediaQuery.of(context).size.width);
      provider.loadInterstitialAd();
    });
  }

  void _fetchUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _userPosition = position;
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
      await Permission.location.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Create Poll"),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: () => AuthServices.signOut(context),
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: const TabBar(
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorColor: Colors.orange,
            unselectedLabelColor: Colors.black,
            labelStyle: TextStyle(
              color: Colors.orange,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Posted'),
              Tab(text: 'Voted'),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: TabBarView(
                  children: [
                    _buildAllPolls(),
                    _buildPostedPolls(),
                    _buildVotedPolls(),
                  ],
                ),
              ),
              Consumer<PollProvider>(
                builder: (context, pollProvider, _) {
                  final bannerAd = pollProvider.bannerAd;
                  if (bannerAd == null) return const SizedBox.shrink();
                  return SizedBox(
                    width: bannerAd.size.width.toDouble(),
                    height: bannerAd.size.height.toDouble(),
                    child: AdWidget(ad: bannerAd),
                  );
                },
              ),
            ],
          ),
        ),
        floatingActionButton: Consumer<PollProvider>(
          builder: (context, pollProvider, _) {
            final bannerHeight =
                pollProvider.bannerAd?.size.height.toDouble() ?? 0;
            return Padding(
              padding: EdgeInsets.only(bottom: bannerHeight),
              child: SpeedDial(
                icon: Icons.add,
                activeIcon: Icons.close,
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                activeBackgroundColor: Colors.orange.shade700,
                activeForegroundColor: Colors.white,
                elevation: 6,
                spacing: 12,
                spaceBetweenChildren: 8,
                overlayOpacity: 0.4,
                tooltip: 'Actions',
                children: [
                  // ── Create Poll ───────────────────────────────────────────
                  SpeedDialChild(
                    child: const Icon(Icons.add_chart_rounded),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    label: 'Create Poll',
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    onTap: () {
                      context.read<PollProvider>().showInterstitialAd(
                        context: context,
                        onAdClosed: () {
                          Navigator.push(
                            context,
                            PageTransition(
                              child:
                                  CreatePollScreen(currentId: _currentUserId),
                              type: PageTransitionType.fade,
                            ),
                          );
                        },
                      );
                    },
                  ),
                  // ── New AI Chat ───────────────────────────────────────────
                  SpeedDialChild(
                    child: const Icon(Icons.chat_bubble_outline_rounded),
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    label: 'New AI Chat',
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    onTap: () {
                      context.read<ChatProvider>().resetForNewChat();
                      Navigator.push(
                        context,
                        PageTransition(
                          child: const ChatScreen(),
                          type: PageTransitionType.fade,
                        ),
                      );
                    },
                  ),
                  // ── Chat History ──────────────────────────────────────────
                  SpeedDialChild(
                    child: const Icon(Icons.history_rounded),
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    label: 'Chat History',
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        PageTransition(
                          child: const ConversationsScreen(),
                          type: PageTransitionType.fade,
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPostedPolls() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('polls')
          .where('creatorId', isEqualTo: _currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.orange),
          );
        }
        final polls = snapshot.data!.docs;
        return polls.isEmpty
            ? const Center(
                child: Text(
                  "No Posted Polls Available",
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: polls.length,
                itemBuilder: (context, index) {
                  final poll = polls[index];
                  return _buildPollCard(poll);
                },
              );
      },
    );
  }

  Widget _buildVotedPolls() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('polls').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.orange),
          );
        }
        final polls = snapshot.data!.docs;

        final votedPolls = polls.where((poll) {
          final options = poll['options'] as List<dynamic>;
          // Check if the current user is in any of the 'voters' lists
          for (var option in options) {
            if (option['voters'] != null &&
                (option['voters'] as List).contains(_currentUserId)) {
              return true;
            }
          }
          return false;
        }).toList();

        return votedPolls.isEmpty
            ? const Center(
                child: Text(
                  "No Voted Poll Available",
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: votedPolls.length,
                itemBuilder: (context, index) {
                  final poll = votedPolls[index];
                  return _buildPollCard(poll, showUserVote: true);
                },
              );
      },
    );
  }

  Widget _buildAllPolls() {
    if (_userPosition == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('polls')
          .where('creatorId', isNotEqualTo: _currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.orange),
          );
        }
        const double maxDistanceInMeters = 5000;
        final allPolls = snapshot.data!.docs;
        final polls = allPolls.where((element) {
          final data = element.data() as Map<String, dynamic>;
          if (data['position'] == null || data['position'] is! GeoPoint) {
            return false;
          }
          final GeoPoint pollPosition = data['position'];
          final double distance = Geolocator.distanceBetween(
            _userPosition!.latitude,
            _userPosition!.longitude,
            pollPosition.latitude,
            pollPosition.longitude,
          );
          return distance <= maxDistanceInMeters;
        }).toList();
        return polls.isEmpty
            ? const Center(
                child: Text(
                  "No Poll Available",
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: polls.length,
                itemBuilder: (context, index) {
                  final poll = polls[index];
                  return _buildPollCard(poll, showUserVote: true);
                },
              );
      },
    );
  }

  Widget _buildPollCard(DocumentSnapshot poll, {bool showUserVote = false}) {
    final data = poll.data() as Map<String, dynamic>;
    final options = data['options'] as List<dynamic>;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and Creator Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      data['title'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(
                color: Colors.orangeAccent,
                thickness: 1,
                height: 20,
              ),
              const SizedBox(height: 10),

              // Options Section
              for (var i = 0; i < options.length; i++) ...[
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 6,
                        spreadRadius: 1,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          options[i]['imageUrl'],
                          height: 50,
                          width: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.image_not_supported,
                                size: 50,
                                color: Colors.grey,
                              ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      // Option Name and Progress
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              options[i]['name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: (options[i]['votes'] ?? 0.0) / 10,
                              color: Colors.orange,
                              backgroundColor: Colors.grey[300],
                            ),
                            if (showUserVote &&
                                options[i]['voters'] != null &&
                                (options[i]['voters'] as List).contains(
                                  _currentUserId,
                                ))
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  '(You voted)',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Vote Button
                      const SizedBox(width: 15),
                      if (showUserVote)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () {
                            ShowPolls.handleVote(
                              poll.id,
                              i,
                              context,
                              _currentUserId,
                            );
                          },
                          child: const Text(
                            'Vote',
                            style: TextStyle(fontSize: 14, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 5),

              if (!showUserVote)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditPollScreen(poll: poll),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      label: const Text(
                        'Edit',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        ShowPolls.deletePoll(poll.id, context);
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
