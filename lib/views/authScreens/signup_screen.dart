import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../global/global_instances.dart';
import '../../global/global_vars.dart';
import '../widgets/custom_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {

  XFile? imageFile;
  ImagePicker pickerImage = ImagePicker();

  TextEditingController nameTextEditingController = TextEditingController();
  TextEditingController emailTextEditingController = TextEditingController();
  TextEditingController passwordTextEditingController = TextEditingController();
  TextEditingController confirmTextEditingController = TextEditingController();

  GlobalKey<FormState> formKey = GlobalKey<FormState>();

  pickImageFromGallery()  async {
     imageFile = await pickerImage.pickImage(source: ImageSource.gallery);

     setState(() {
       imageFile;
     });
  }



  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 11,),
          InkWell(
            onTap: () {
              pickImageFromGallery();
            },
            child: CircleAvatar(
              radius: MediaQuery.of(context).size.width * 0.20,
              backgroundColor: Colors.white,
              backgroundImage: imageFile == null? null: FileImage(File(imageFile!.path)),
              child: imageFile == null?
              Icon(
                Icons.add_photo_alternate,
                size: MediaQuery.of(context).size.width * 0.20,
                color: Colors.grey
              ) : null,
            ),
          ),

          const SizedBox(height: 11,),

          Form(
              key: formKey,
              child: Column(
                children: [
                  CustomeTextField(
                    textEditingController: nameTextEditingController,
                    iconData: Icons.person,
                    hintString: "Name",
                    isObsecure: false,
                    enable: true,
                  ),
                  CustomeTextField(
                    textEditingController: emailTextEditingController,
                    iconData: Icons.email,
                    hintString: "Email",
                    isObsecure: false,
                    enable: true,
                  ),

                  CustomeTextField(

                    textEditingController: passwordTextEditingController,
                    iconData: Icons.lock,
                    hintString: "Password",
                    isObsecure: true,
                    enable: true,
                  ),

                  CustomeTextField(
                    textEditingController: confirmTextEditingController,
                    iconData: Icons.lock,
                    hintString: "Confirm Password",
                    isObsecure: true,
                    enable: true,
                  ),

                  const SizedBox(height: 11,),

                  ElevatedButton(
                    onPressed: () async {
                      await authViewModel.validateSignUpForm(
                          imageFile,
                          passwordTextEditingController.text.trim(),
                          confirmTextEditingController.text.trim(),
                          emailTextEditingController.text.trim(),
                          nameTextEditingController.text.trim(),
                          context
                      );
                    },
                    child: const Text(
                      "Sign Up",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 10,),
                    ),
                  ),
                  const SizedBox(height: 37,),

                ],
              )),
        ],
      ),
    );
  }
}
