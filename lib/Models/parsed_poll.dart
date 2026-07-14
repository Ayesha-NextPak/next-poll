/// Holds the AI-suggested poll data parsed from a chat message.
class ParsedPoll {
  final String title;
  final List<String> options; // always exactly 3

  const ParsedPoll({required this.title, required this.options})
      : assert(options.length == 3);

  @override
  String toString() =>
      'ParsedPoll(title: $title, options: $options)';
}
