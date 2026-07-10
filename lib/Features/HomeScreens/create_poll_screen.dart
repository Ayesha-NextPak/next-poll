// ignore_for_file: library_private_types_in_public_api, must_be_immutable, use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:next_poll/Features/HomeScreens/map_screen.dart';
import 'package:next_poll/Features/Provider/poll_provider.dart';
import 'package:provider/provider.dart';

class CreatePollScreen extends StatelessWidget {
  final String currentId;
  const CreatePollScreen({super.key, required this.currentId});

  @override
  Widget build(BuildContext context) {
    return Consumer<PollProvider>(
      builder: (context, pollProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Create a new Poll"),
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
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
                      child: TextFormField(
                        controller: pollProvider.titleController,
                        decoration:
                            const InputDecoration(labelText: 'Poll Title'),
                      ),
                    ),
                    for (int i = 0; i < 3; i++)
                      Container(
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.all(10.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                          border:
                              Border.all(color: Colors.grey.withOpacity(0.2)),
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
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller:
                                    pollProvider.optionNameControllers[i],
                                decoration: InputDecoration(
                                    labelText: 'Option ${i + 1} Name'),
                              ),
                            ),
                            const SizedBox(width: 15),
                            GestureDetector(
                              onTap: () => pollProvider.pickImage(i),
                              child: pollProvider.optionImages[i] != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.file(
                                        pollProvider.optionImages[i]!,
                                        height: 50,
                                        width: 50,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Container(
                                      height: 50,
                                      width: 50,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.image),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    pollProvider.isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.orangeAccent,
                          )
                        : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orangeAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                ),
                                onPressed: () =>
                                    pollProvider.checkSubmissionPossible(currentId, context),
                                child: const Text('Create Poll',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.white)),
                              ),
                              SizedBox(width: 10,),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orangeAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                ),
                                onPressed: () 
                                async {
                                  final LatLng? result = await Navigator.push(context, MaterialPageRoute(builder: ((context) => const MapScreen())));
                                  if(result!=null)
                                  {
                                    pollProvider.latlng = GeoPoint(result.latitude, result.longitude); 
                                  }
                                }
                                   ,
                                child: const Text('Choose Location',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.white)),
                              ),
                          ],
                        ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
