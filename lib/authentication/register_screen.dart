import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as fStorage;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riders_app/global/global.dart';
import 'package:riders_app/widgets/custom_text_field.dart';
import 'package:riders_app/widgets/error_dialog.dart';
import 'package:riders_app/widgets/loading_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController comfirmPasswordController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController locationController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  XFile? imageXFile;
  final ImagePicker _picker = ImagePicker();
  Position? position;
  List<Placemark>? placeMarks;

  String sellerImageUrl = '';
  String completeAddress = '';

  // get image from gallery
  Future<void> _getImage() async {
    imageXFile = await _picker.pickImage(source: ImageSource.gallery);

    setState(() {
      imageXFile;
    });
  }

  getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    Position newPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    position = newPosition;
    placeMarks = await placemarkFromCoordinates(
      position!.latitude,
      position!.longitude,
    );

    Placemark pMark = placeMarks![0];
    completeAddress =
        '${pMark.subThoroughfare} ${pMark.thoroughfare}, ${pMark.subLocality} ${pMark.locality}, ${pMark.subAdministrativeArea}, ${pMark.administrativeArea} ${pMark.postalCode}, ${pMark.country}';

    locationController.text = completeAddress;
    print(position);
  }

  Future<void> formValidation() async {
    if (imageXFile == null) {
      showDialog(
        context: context,
        builder: (c) {
          return const ErrorDialog(
            message: 'Please select an image!',
          );
        },
      );
    } else {
      if (passwordController.text == comfirmPasswordController.text) {
        if (comfirmPasswordController.text.isNotEmpty &&
            emailController.text.isNotEmpty &&
            nameController.text.isNotEmpty &&
            phoneController.text.isNotEmpty &&
            locationController.text.isNotEmpty) {
          //uploading image
          showDialog(
            context: context,
            builder: (c) {
              return const LoadingDialog(
                message: 'Registering account',
              );
            },
          );

          String fileName = DateTime.now().millisecondsSinceEpoch.toString();
          fStorage.Reference reference = fStorage.FirebaseStorage.instance
              .ref()
              .child('riders')
              .child(fileName);
          fStorage.UploadTask uploadTask =
              reference.putFile(File(imageXFile!.path));
          fStorage.TaskSnapshot taskSnapshot =
              await uploadTask.whenComplete(() {});
          await taskSnapshot.ref.getDownloadURL().then((url) {
            sellerImageUrl = url;

            //save info to firestore
            authenticateSellerAndSignUp();
          });
        } else {
          showDialog(
            context: context,
            builder: (c) {
              return const ErrorDialog(
                message: 'Please write the required inro for registration',
              );
            },
          );
        }
      } else {
        showDialog(
          context: context,
          builder: (c) {
            return const ErrorDialog(
              message: 'Password do not match!',
            );
          },
        );
      }
    }
  }

  void authenticateSellerAndSignUp() async {
    User? currentUser;
    await firebaseAuth
        .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim())
        .then((auth) {
      currentUser = auth.user;
    }).catchError((error) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (c) {
          return ErrorDialog(
            message: error.message.toString(),
          );
        },
      );
    });

    if (currentUser != null) {
      saveDataToFirestore(currentUser!).then((value) {
        Navigator.pop(context);
        //send user to HomePage
        //Route newRoute = MaterialPageRoute(builder: (c) => const HomeScreen());
        //Navigator.pushReplacement(context, newRoute);
      });
    }
  }

  Future saveDataToFirestore(User currentUser) async {
    FirebaseFirestore.instance.collection('riders').doc(currentUser.uid).set(
      {
        'riderUID': currentUser.uid,
        'riderEmail': currentUser.email,
        'riderName': nameController.text.trim(),
        'ridererAvatarUrl': sellerImageUrl,
        'phone': phoneController.text.trim(),
        'adress': completeAddress,
        'status': 'approved',
        'earnings': 0.0,
        'lat': position!.latitude,
        'lng': position!.longitude,
      },
    );

    //save data locally
    sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences!.setString('uid', currentUser.uid);
    await sharedPreferences!.setString('email', currentUser.email.toString());
    await sharedPreferences!.setString('name', nameController.text.trim());
    await sharedPreferences!.setString('photoUrl', sellerImageUrl);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          const SizedBox(
            height: 10,
          ),
          InkWell(
            onTap: () {
              _getImage();
            },
            child: CircleAvatar(
              radius: MediaQuery.of(context).size.width * 0.20,
              backgroundColor: Colors.white,
              backgroundImage:
                  imageXFile == null ? null : FileImage(File(imageXFile!.path)),
              child: imageXFile == null
                  ? const Icon(
                      Icons.add_photo_alternate,
                      size: 100, //MediaQuery.of(context).size.width * 50,
                      color: Colors.grey,
                    )
                  : null,
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          Form(
            key: _formKey,
            child: Column(
              children: [
                CustomTextField(
                  data: Icons.person,
                  controller: nameController,
                  hintText: 'Name',
                  isObsecre: false,
                ),
                CustomTextField(
                  data: Icons.email,
                  controller: emailController,
                  hintText: 'Email',
                  isObsecre: false,
                ),
                CustomTextField(
                  data: Icons.lock,
                  controller: passwordController,
                  hintText: 'Password',
                  isObsecre: true,
                ),
                CustomTextField(
                  data: Icons.lock,
                  controller: comfirmPasswordController,
                  hintText: 'Confirm password',
                  isObsecre: true,
                ),
                CustomTextField(
                  data: Icons.phone,
                  controller: phoneController,
                  hintText: 'Phone',
                  isObsecre: false,
                ),
                CustomTextField(
                  data: Icons.my_location,
                  controller: locationController,
                  hintText: 'My current adress',
                  isObsecre: false,
                  enabled: true,
                ),
                Container(
                  width: 400,
                  height: 40,
                  alignment: Alignment.center,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      getCurrentLocation();
                    },
                    icon: const Icon(
                      Icons.location_on,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Get my Current Location',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      primary: Colors.amber,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 30,
          ),
          ElevatedButton(
            child: const Text(
              'Sign Up',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              primary: Colors.purple,
              padding: const EdgeInsets.symmetric(
                horizontal: 100,
                vertical: 10,
              ),
            ),
            onPressed: () {
              formValidation();
            },
          ),
        ],
      ),
    );
  }
}
