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
  String fileId = ""; //this refers to the id given to the file created on google drive
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

         ga.File x  = await drive.files.create(fileToUpload,
            uploadMedia: ga.Media(file.openRead(), file.lengthSync()));

        if (x.id != null) {
          print(x.id!); // this refers to the id of the file created in Google Drive
          setState(() {
            fileId = x.id!; //we save it in a variable called fileId
          });
        }

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
 
  
  //Import back database to the app from Google Drive
  downloadFromGoogleDrive() async {
    try { 
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: clientId,
 
        scopes: <String>[ga.DriveApi.driveFileScope],
      );
     
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    
      if (googleUser != null) {
        final auth.AuthClient? client =
             await googleSignIn.authenticatedClient();
       
        final dir = await getApplicationDocumentsDirectory();
     
        var drive = ga.DriveApi(client!); 

         final listOfFiles = await drive.files.list(q: "db_backup.isar");

         String _fileId = listOfFiles.files![0].id      
        
        //here we get the file that we uploaded to Google Drive using its id. 
        final downloadedFile = await drive.files.get(_fileId,
            downloadOptions: ga.DownloadOptions.fullMedia) as Media;
    
        final List<List<int>> chunks = [];

        await for (List<int> chunk in downloadedFile.stream) {
          chunks.add(chunk);
        }
        
        final List<int> bytes = chunks.expand((chunk) => chunk).toList();
        
        //first close isar database
        await isar.close();

        final dbFile =
            await fa.File('${dir.path}/database_you_want_to_import.isar').writeAsBytes(bytes);
        final dbPath = p.join(dir.path, 'default.isar');

        if (await dbFile.exists()) {
          await dbFile.copy(dbPath);
        }
 
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Failed to log in")));
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
