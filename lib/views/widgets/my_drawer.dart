import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../global/global_instances.dart';
import '../../global/global_vars.dart';
import '../mainScreens/home_screen.dart';
import '../splashScreen/splash_screen.dart';


class MyDrawer extends StatefulWidget {
  const MyDrawer({super.key});

  @override
  State<MyDrawer> createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [

          //header
          Container(
            padding: EdgeInsets.only(top:  25, bottom: 10),
            child: Column(

              children: [
                Material(
                  borderRadius: const BorderRadius.all(Radius.circular(81)),
                  elevation: 8,
                  child: SizedBox(
                    height: 158,
                    width: 158,
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(sharedPreferences!.getString("imageUrl").toString()),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),

                Text(sharedPreferences!.getString("name").toString(),
                 style: TextStyle(
                   color: Colors.white,
                   fontSize: 18,
                   fontWeight: FontWeight.bold
                 ),
                )
              ],
            ),
          ),

          // body
          Column(

            children: [
              const Divider(
                height: 10,
                  color: Colors.grey,
                thickness: 2,

              ),
              ListTile(
                leading: const Icon(Icons.home, color: Colors.white,),
                title: const Text(
                  "Home",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                 onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => HomeScreen()));
                 },

              ),

              const Divider(
                height: 10,
                color: Colors.grey,
                thickness: 2,

              ),
              ListTile(
                leading: const Icon(Icons.reorder, color: Colors.white,),
                title: const Text(
                  "My Orders",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => HomeScreen()));
                },

              ),

              const Divider(
                height: 10,
                color: Colors.grey,
                thickness: 2,

              ),
              ListTile(
                leading: const Icon(Icons.access_time, color: Colors.white,),
                title: const Text(
                  "History",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => HomeScreen()));
                },

              ),

              const Divider(
                height: 10,
                color: Colors.grey,
                thickness: 2,

              ),
              ListTile(
                leading: const Icon(Icons.search, color: Colors.white,),
                title: const Text(
                  "Search Specific Restaurants",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => HomeScreen()));
                },

              ),

              const Divider(
                height: 10,
                color: Colors.grey,
                thickness: 2,

              ),
              ListTile(
                leading: const Icon(Icons.add_location, color: Colors.white,),
                title: const Text(
                  "Add New Address",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () {

                  // commonViewModel.updateLocationInDatabase();
                  // commonViewModel.showSnackBar(
                  //     "Your address has been added successfully",
                      //context

                },

              ),

              const Divider(
                height: 10,
                color: Colors.grey,
                thickness: 2,

              ),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.white,),
                title: const Text(
                  "Sign Out",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  FirebaseAuth.instance.signOut();
                  Navigator.push(context, MaterialPageRoute(builder: (context) => MySplashScreen()));
                },

              ),
            ],

          )
        ],
      ),
    );
  }
}
