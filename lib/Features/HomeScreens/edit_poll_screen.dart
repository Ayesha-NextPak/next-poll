import 'package:flutter/material.dart';
import 'package:next_poll/Features/Provider/poll_provider.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditPollScreen extends StatefulWidget {
  final DocumentSnapshot poll;
  const EditPollScreen({super.key, required this.poll});

  @override
  EditPollScreenState createState() => EditPollScreenState();
}

class EditPollScreenState extends State<EditPollScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<PollProvider>(context, listen: false);
    provider.initializePoll(widget.poll);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Poll"),
        centerTitle: true,
      ),
      body: Consumer<PollProvider>(
        builder: (_, pollProvider, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Poll title field
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
                        validator: (value) =>
                            value!.isEmpty ? 'Title is required' : null,
                      ),
                    ),
                    // Options fields
                    for (int i = 0;
                        i < pollProvider.optionNameControllers.length;
                        i++)
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Option name
                            Expanded(
                              child: TextFormField(
                                controller:
                                    pollProvider.optionNameControllers[i],
                                decoration: InputDecoration(
                                    labelText: 'Option ${i + 1} Name'),
                                validator: (value) => value!.isEmpty
                                    ? 'Option ${i + 1} name is required'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 15),
                            // Option image
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
                                  : pollProvider.existingImageUrls[i] != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Image.network(
                                            pollProvider.existingImageUrls[i]!,
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
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Submit button
                    pollProvider.isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.orangeAccent,
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                await pollProvider.updatePoll(
                                    context, widget.poll.id);
                              }
                            },
                            child: const Text(
                              'Save Changes',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.white),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
