import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

void main() {
  runApp(const LearningApp());
}

class LearningApp extends StatelessWidget {
  const LearningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ChapterListPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// CHAPTER LIST PAGE
class ChapterListPage extends StatefulWidget {
  @override
  State<ChapterListPage> createState() => _ChapterListPageState();
}

class _ChapterListPageState extends State<ChapterListPage> {
  List chapters = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  _load() async {
    final p = await SharedPreferences.getInstance();
    final data = p.getString("chapters");
    if (data != null) chapters = jsonDecode(data);
    setState(() {});
  }

  _save() async {
    final p = await SharedPreferences.getInstance();
    p.setString("chapters", jsonEncode(chapters));
  }

  _addChapter() async {
    TextEditingController c = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("New Chapter"),
        content: TextField(controller: c),
        actions: [
          TextButton(
            onPressed: () {
              chapters.add({
                "title": c.text,
                "video": null,
                "pdf": null,
                "quiz": [],
                "watched": false,
                "pdfRead": false,
                "quizPassed": false
              });
              _save();
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Learning App")),
      floatingActionButton: FloatingActionButton(
        onPressed: _addChapter,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: chapters.length,
        itemBuilder: (_, i) {
          final ch = chapters[i];
          bool completed =
              ch["watched"] && ch["pdfRead"] && ch["quizPassed"];

          return ListTile(
            title: Text(ch["title"]),
            subtitle: Text(completed ? "Completed" : "Pending"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChapterPage(
                    chapter: ch,
                    onSave: () {
                      _save();
                      setState(() {});
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// CHAPTER PAGE
class ChapterPage extends StatefulWidget {
  final Map chapter;
  final Function onSave;

  const ChapterPage({required this.chapter, required this.onSave});

  @override
  State<ChapterPage> createState() => _ChapterPageState();
}

class _ChapterPageState extends State<ChapterPage> {
  @override
  Widget build(BuildContext context) {
    final ch = widget.chapter;

    return Scaffold(
      appBar: AppBar(title: Text(ch["title"])),
      body: ListView(
        children: [
          ListTile(
            title: Text("Add / Play Video"),
            onTap: () async {
              if (ch["video"] == null) {
                FilePickerResult? r =
                    await FilePicker.platform.pickFiles(type: FileType.video);

                if (r != null) {
                  ch["video"] = r.files.single.path;
                  widget.onSave();
                  setState(() {});
                }
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoPlayPage(
                      file: File(ch["video"]),
                      onComplete: () {
                        ch["watched"] = true;
                        widget.onSave();
                      },
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            title: Text("Add / View PDF"),
            onTap: () async {
              if (ch["pdf"] == null) {
                FilePickerResult? r = await FilePicker.platform.pickFiles(
                    type: FileType.custom, allowedExtensions: ["pdf"]);
                if (r != null) {
                  ch["pdf"] = r.files.single.path;
                  widget.onSave();
                  setState(() {});
                }
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PDFViewPage(
                      filePath: ch["pdf"],
                      onRead: () {
                        ch["pdfRead"] = true;
                        widget.onSave();
                      },
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            title: Text("Quiz"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuizPage(
                    questions: ch["quiz"],
                    onPass: () {
                      ch["quizPassed"] = true;
                      widget.onSave();
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// VIDEO PAGE
class VideoPlayPage extends StatefulWidget {
  final File file;
  final VoidCallback onComplete;

  const VideoPlayPage({required this.file, required this.onComplete});

  @override
  State<VideoPlayPage> createState() => _VideoPlayPageState();
}

class _VideoPlayPageState extends State<VideoPlayPage> {
  late VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        setState(() {});
        controller.play();

        controller.addListener(() {
          if (controller.value.position.inSeconds >
              controller.value.duration.inSeconds * 0.9) {
            widget.onComplete();
          }
        });
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Watch Video")),
      body: controller.value.isInitialized
          ? Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

// PDF PAGE
class PDFViewPage extends StatefulWidget {
  final String filePath;
  final VoidCallback onRead;

  const PDFViewPage({required this.filePath, required this.onRead});

  @override
  State<PDFViewPage> createState() => _PDFViewPageState();
}

class _PDFViewPageState extends State<PDFViewPage> {
  int seconds = 0;

  @override
  void initState() {
    super.initState();

    Timer.periodic(const Duration(seconds: 1), (t) {
      seconds++;
      if (seconds == 20) widget.onRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Read PDF")),
      body: PDFView(filePath: widget.filePath),
    );
  }
}

// QUIZ PAGE
class QuizPage extends StatefulWidget {
  final List questions;
  final VoidCallback onPass;

  const QuizPage({required this.questions, required this.onPass});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int score = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text("Quiz")),
        body: Center(child: Text("No questions added!")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Quiz")),
      body: ListView.builder(
        itemCount: widget.questions.length,
        itemBuilder: (_, i) {
          final q = widget.questions[i];

          return ListTile(
            title: Text(q["q"]),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(q["opt"].length, (j) {
                return TextButton(
                  onPressed: () {
                    if (q["opt"][j] == q["ans"]) score++;

                    if (i == widget.questions.length - 1) {
                      if (score >= (widget.questions.length / 2)) {
                        widget.onPass();
                      }
                      Navigator.pop(context);
                    }
                  },
                  child: Text(q["opt"][j]),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}
