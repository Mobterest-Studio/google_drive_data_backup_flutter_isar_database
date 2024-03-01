import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:googleapis/drive/v3.dart' as ga;
import 'collections/task.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth show AuthClient;
import 'dart:io' as fa;
import 'package:path/path.dart' as p;

late Isar isar;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = await getApplicationDocumentsDirectory();

  if (Isar.instanceNames.isEmpty) {
    isar = await Isar.open([TaskSchema],
        directory: dir.path, name: 'taskInstance');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'How to upload isar database to Google Drive',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const Home());
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final clientId = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: Center(
        child: ElevatedButton(
            onPressed: () {
              uploadToGoogleDrive();
            },
            child: const Text("Upload Isar DB to Google Drive")),
      )),
    );
  }

  uploadToGoogleDrive() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: clientId, scopes: [ga.DriveApi.driveFileScope]);

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser != null) {
        final auth.AuthClient? client =
            await googleSignIn.authenticatedClient();

        final dir = await getApplicationDocumentsDirectory();

        fa.File file = fa.File("${dir.path}/db_backup.isar");
        await isar.copyToFile("${dir.path}/db_backup.isar");

        ga.File fileToUpload = ga.File();
        DateTime now = DateTime.now();

        fileToUpload.name =
            "${now.toIso8601String()}_${p.basename(file.absolute.path)}";

        final drive = ga.DriveApi(client!);

        await drive.files.create(fileToUpload,
            uploadMedia: ga.Media(file.openRead(), file.lengthSync()));

        if (file.existsSync()) {
          file.deleteSync();
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Failed to sign in")));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
