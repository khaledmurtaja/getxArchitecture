import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getx_architecture/App/modules/traineeHome/widgets/trainingDatesDialog.dart';

import '../../data/models/ad.dart';
import '../../data/models/training.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class TraineeHomeController extends GetxController {
  final RxInt balance = 0.obs;
  final ads = <Ad>[].obs;
  int selectedIndex = -1;

  final RxList<Training> recommendedTrainings = <Training>[].obs;
  final RxList<Training> newTrainings = <Training>[].obs;

  final RxBool isLoadingRecommendedTrainings = true.obs;
  final RxBool isLoadingNewTrainings = true.obs;

  final CollectionReference trainingsCollection =
      FirebaseFirestore.instance.collection('trainings');
  static TraineeHomeController get to => Get.find();
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  // Future<void> trackUserActivity(String activity) async {
  //   await analytics.logEvent(
  //     name: 'hhhhhhh',
  //     parameters: {'activity': activity},
  //   );
  // }

  @override
  void onInit() {
    super.onInit();
    fetchTraineeData();
    fetchAds();
    fetchRecommendedTrainings('mobile development');
    fetchNewTrainingsTrainings();
  }

  void fetchAds() async {
    // await trackUserActivity('fetchAds');
    try {
      final querySnapshot =
          await FirebaseFirestore.instance.collection('ads').get();

      final List<Ad> allAds = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Ad(imageUrl: data['imageUrl'], name: data['name']);
      }).toList();

      final random = Random();
      final List<Ad> randomAds = [];

      while (randomAds.length < 3 && allAds.isNotEmpty) {
        final randomIndex = random.nextInt(allAds.length);
        randomAds.add(allAds[randomIndex]);
        allAds.removeAt(randomIndex);
      }

      ads.value = randomAds;
    } catch (e) {
      print('Error fetching ads: $e');
    }
  }

  Future<void> fetchRecommendedTrainings(String category) async {
    try {
      final userId = 'XLPFZgHwDtjhzzjG3vRk';

      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      List<dynamic> registeredTrainingIds =
          userSnapshot.data()!['selected_training_ids'] ?? [];
      final snapshot = registeredTrainingIds.isEmpty
          ? await trainingsCollection
              .where('category', isEqualTo: category)
              .get()
          : await trainingsCollection
              .where('category', isEqualTo: category)
              .where(FieldPath.documentId, whereNotIn: registeredTrainingIds)
              .get();

      final List<Training> fetchedTrainings = snapshot.docs.map((document) {
        return Training(
          name: document['trainingName'],
          description: document['description'],
          isPaidCourse: document['isPaidCourse'],
          price: document['price'],
          dates: List<Map<String, dynamic>>.from(document['dates']),
          category: '',
          id: document.id,
          imageUrl: document['courseImageUrl'],
          advisorName: document['advisorName'],
          advisorId: document['advisorId'],
        );
      }).toList();
      recommendedTrainings.assignAll(fetchedTrainings);
    } catch (error) {
      // Handle error
    } finally {
      isLoadingRecommendedTrainings.value = false;
    }
  }

  Future<void> fetchNewTrainingsTrainings() async {
    try {
      final traineeSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc('XLPFZgHwDtjhzzjG3vRk')
          .get();
      List<dynamic> registeredTrainingIds =
          traineeSnapshot.data().toString().contains('selected_training_ids')
              ? traineeSnapshot.data()!['selected_training_ids']
              : [];

      final snapshot = registeredTrainingIds.isEmpty
          ? await trainingsCollection.get()
          : await trainingsCollection
              .where(FieldPath.documentId, whereNotIn: registeredTrainingIds)
              .get();

      final List<Training> fetchedTrainings = snapshot.docs.map((document) {
        print(document.id);
        return Training(
            name: document['trainingName'],
            description: document['description'],
            isPaidCourse: document['isPaidCourse'],
            price: document['price'],
            dates: List<Map<String, dynamic>>.from(document['dates']),
            category: '',
            id: document.id,
            imageUrl: document['courseImageUrl'],
            advisorName: document['advisorName'],
            advisorId: document['advisorId']);
      }).toList();
      print(fetchedTrainings.length);
      newTrainings.assignAll(fetchedTrainings);
      update();
    } catch (error) {
      print("error hhh $error");
      // Handle error
    } finally {
      isLoadingNewTrainings.value = false;
    }
  }

  Future<void> showTrainingDatesDialog(
    BuildContext context,
    Training training,
    TraineeHomeController traineeHomeController,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return TrainingDatesDialog(
          training: training,
          traineeHomeController: traineeHomeController,
        );
      },
    );
  }

  void indicatorUpdate() {
    selectedIndex = -1;
    update();
  }

  void recordTraining(BuildContext context, Training training,
      Map<String, dynamic> selectedDate) {
    final userId = 'XLPFZgHwDtjhzzjG3vRk';

    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('selected_training_ids_times')
        .get()
        .then((querySnapshot) {
      if (querySnapshot.docs.isNotEmpty) {
        bool hasConflict = false;

        for (var doc in querySnapshot.docs) {
          List<dynamic> dates = doc.data()['dates'];

          for (var date in dates) {
            if (checkConflict(selectedDate, date)) {
              hasConflict = true;
              break;
            }
          }
          if (hasConflict) {
            break;
          }
        }

        if (hasConflict) {
          Get.snackbar(
            'An error occurred!',
            'Conflicting training date. Please choose a different date.',
            snackPosition: SnackPosition.BOTTOM,
            colorText: Colors.white,
            backgroundColor: Colors.redAccent,
            icon: const Icon(Icons.add_alert),
          );
        } else {
          if (training.isPaidCourse) {
            FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get()
                .then((userSnapshot) {
              double traineeBalance = 0.0;
              if (userSnapshot.data()!.containsKey('balance')) {
                traineeBalance = double.parse(userSnapshot.data()!['balance']);
              } else {}

              // double traineeBalance = double.parse($group1);
              // userSnapshot.data()!['balance'] ?? 0.0;

              if (traineeBalance >= training.price) {
                double updatedBalance = traineeBalance - training.price;

                FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .update({
                  'balance': updatedBalance,
                }).then((_) {
                  saveTrainingData(context, training, selectedDate);
                }).catchError((error) {
                  Get.snackbar(
                    'An error occurred!',
                    'Failed to deduct course price from balance',
                    snackPosition: SnackPosition.BOTTOM,
                    colorText: Colors.white,
                    backgroundColor: Colors.redAccent,
                    icon: const Icon(Icons.add_alert),
                  );
                });
              } else {
                Get.snackbar(
                  'An error occurred!',
                  'Insufficient balance for the course',
                  snackPosition: SnackPosition.BOTTOM,
                  colorText: Colors.white,
                  backgroundColor: Colors.redAccent,
                  icon: const Icon(Icons.add_alert),
                );
              }
            }).catchError((error) {
              print('object $error');

              Get.snackbar(
                'An error occurred!',
                'Failed to retrieve trainee data',
                snackPosition: SnackPosition.BOTTOM,
                colorText: Colors.white,
                backgroundColor: Colors.redAccent,
                icon: const Icon(Icons.add_alert),
              );
            });
          } else {
            saveTrainingData(context, training, selectedDate);
          }
        }
      } else {
        saveTrainingData(context, training, selectedDate);

        // The collection "selected_training_ids_times" does not exist for the user
        // Handle this case accordingly
      }
    }).catchError((error) {
      print('object $error');
      Get.snackbar(
        'An error occurred!',
        'Failed to retrieve previously selected training dates',
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.add_alert),
      );
    });
  }

/*
  void recordTraining(BuildContext context, Training training,
      Map<String, dynamic> selectedDate) {
    final userId = 'XLPFZgHwDtjhzzjG3vRk';

    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('selected_training_ids_times')
        .get()
        .then((querySnapshot) {
      bool hasConflict = false;

      for (var doc in querySnapshot.docs) {
        List<dynamic> dates = doc.data()['dates'];

        for (var date in dates) {
          if (checkConflict(selectedDate, date)) {
            hasConflict = true;
            break;
          }
        }
        if (hasConflict) {
          break;
        }
      }

      if (hasConflict) {
        Get.snackbar(
          'An error occurred!',
          'Conflicting training date. Please choose a different date.',
          snackPosition: SnackPosition.BOTTOM,
          colorText: Colors.white,
          backgroundColor: Colors.redAccent,
          icon: const Icon(Icons.add_alert),
        );
      } else {
        if (training.isPaidCourse) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get()
              .then((userSnapshot) {
            double traineeBalance = userSnapshot.data()!['balance'] ?? 0.0;

            if (traineeBalance >= training.price) {
              double updatedBalance = traineeBalance - training.price;

              FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .update({
                'balance': updatedBalance,
              }).then((_) {
                saveTrainingData(context, training, selectedDate);
              }).catchError((error) {
                Get.snackbar(
                  'An error occurred!',
                  'Failed to deduct course price from balance',
                  snackPosition: SnackPosition.BOTTOM,
                  colorText: Colors.white,
                  backgroundColor: Colors.redAccent,
                  icon: const Icon(Icons.add_alert),
                );
              });
            } else {
              Get.snackbar(
                'An error occurred!',
                'Insufficient balance for the course',
                snackPosition: SnackPosition.BOTTOM,
                colorText: Colors.white,
                backgroundColor: Colors.redAccent,
                icon: const Icon(Icons.add_alert),
              );
            }
          }).catchError((error) {
            Get.snackbar(
              'An error occurred!',
              'Failed to retrieve trainee data',
              snackPosition: SnackPosition.BOTTOM,
              colorText: Colors.white,
              backgroundColor: Colors.redAccent,
              icon: const Icon(Icons.add_alert),
            );
          });
        } else {
          saveTrainingData(context, training, selectedDate);
        }
      }
    }).catchError((error) {
      print('object $error');
      Get.snackbar(
        'An error occurred!',
        'Failed to retrieve previously selected training dates',
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.add_alert),
      );
    });
  }
*/
  bool checkConflict(
      Map<String, dynamic> selectedDate, Map<String, dynamic> registeredDate) {
    String selectedDay = selectedDate['day'];
    String selectedStartHour = selectedDate['startHour'];
    String selectedEndHour = selectedDate['endHour'];

    String registeredDay = registeredDate['day'];
    String registeredStartHour = registeredDate['startHour'];
    String registeredEndHour = registeredDate['endHour'];

    if (selectedDay == registeredDay) {
      if (selectedStartHour.toString() == registeredStartHour.toString() &&
          selectedEndHour.toString() == registeredEndHour.toString()) {
        print(selectedStartHour.toString() == registeredStartHour.toString() &&
            selectedEndHour.toString() == registeredEndHour.toString());
        return true;
      }
    }

    return false;
  }

  void saveTrainingData(BuildContext context, Training training,
      Map<String, dynamic> selectedDate) {
    final userId = 'XLPFZgHwDtjhzzjG3vRk';

    FirebaseFirestore.instance.collection('users').doc(userId).update({
      'selected_training_ids': FieldValue.arrayUnion([training.id]),
    }).then((_) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('selected_training_ids_times')
          .doc(training.id)
          .set({
        'dates': [selectedDate],
      }).then((_) {
        recommendedTrainings.clear();
        newTrainings.clear();
        isLoadingNewTrainings.value = true;

        isLoadingRecommendedTrainings.value = true;
        fetchNewTrainingsTrainings();
        fetchRecommendedTrainings('mobile development');
        Get.snackbar(
          'The operation succeeded !',
          "Training recorded successfully",
          snackPosition: SnackPosition.BOTTOM,
          colorText: Colors.white,
          backgroundColor: Colors.green,
          icon: const Icon(Icons.add_alert),
        );
      }).catchError((error) {
        Get.snackbar(
          'An error occurred !',
          "Failed to save training date",
          snackPosition: SnackPosition.BOTTOM,
          colorText: Colors.white,
          backgroundColor: Colors.redAccent,
          icon: const Icon(Icons.add_alert),
        );
      });
    }).catchError((error) {
      Get.snackbar(
        'An error occurred !',
        "Failed to update selected training IDs",
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.white,
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.add_alert),
      );
    });
  }

  void fetchTraineeData() async {
    try {
      final DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc('XLPFZgHwDtjhzzjG3vRk')
          .get();

      if (snapshot.exists) {
        final traineeData = snapshot.data() as Map<String, dynamic>?;
        balance.value = int.parse(traineeData?['balance']) ?? 0;
      }
    } catch (error) {
      print('Error fetching trainee data: $error');
    }
  }

  void addBalance(int amount, String trainingId) {
    balance.value += amount;

    FirebaseFirestore.instance
        .collection('users')
        .doc(trainingId)
        .set({'balance': balance.value}, SetOptions(merge: true)).then((_) {
      print('Balance updated successfully');
    }).catchError((error) {
      print('Error updating balance: $error');
    });
  }
}


/*
  void recordTraining(BuildContext context, Training training,
      Map<String, dynamic> selectedDate) {
    final userId = 'XLPFZgHwDtjhzzjG3vRk';



    FirebaseFirestore.instance.collection('users').doc(userId).update({
      'selected_training_ids': FieldValue.arrayUnion([training.id]),
    }).then((_) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('selected_training_ids_times')
          .doc(training.id)
          .set({
        'dates': [selectedDate],
      }).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Training recorded successfully')),
        );
      }).catchError((error) {});
    });
  }
*/
/*
  void showAddBalanceDialog() {
    showDialog(
      context: Get.context!,
      builder: (context) {
        final TextEditingController balanceController = TextEditingController();
        final TextEditingController cardNumberController =
            TextEditingController();

        return AlertDialog(
          title: const Text('Add Balance'),
          content: Container(
            width: double.maxFinite,
            child: Column(
              children: [
                TextField(
                  controller: cardNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Card Number',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: balanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Enter Balance Amount',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Get.back();
              },
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                final int amount = int.tryParse(balanceController.text) ?? 0;
                addBalance(amount, 'XLPFZgHwDtjhzzjG3vRk');
                Get.back();
              },
            ),
          ],
        );
      },
    );
  }
*/


/*
  Future<void> showTrainingDatesDialog(BuildContext context, Training training,
      TraineeHomeController traineeHomeController) async {
    final selectedDate = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select a date'),
          content: Container(
            height: 200,
            width: double.maxFinite,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: training.dates.length,
              itemBuilder: (BuildContext context, int position) {
                return InkWell(
                    onTap: () {
                      selectedIndex = position;
                      traineeHomeController.update();
                      update();
                    },
                    child: Container(
                      width: 150,
                      child: Card(
                        shape: (selectedIndex == position)
                            ? const RoundedRectangleBorder(
                                side: BorderSide(color: Colors.green, width: 2))
                            : null,
                        elevation: 5,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            Row(
                              children: [
                                Text('Day:'),
                                Text(
                                    training.dates[position]['day'].toString()),
                              ],
                            ),
                            Row(
                              children: [
                                Text('Start Hour:'),
                                Text(training.dates[position]['startHour']
                                    .toString()),
                              ],
                            ),
                            Row(
                              children: [
                                Text('End Hour:'),
                                Text(training.dates[position]['endHour']
                                    .toString()),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ));
              },
            ),
          ),
          /*
           SingleChildScrollView(
            child: Column(
              children: training.dates
                  .map(
                    (date) => ListTile(
                      title: Text(date['startHour'].toString()),
                      subtitle: Text(date['endHour'].toString()),
                      onTap: () {
                        Navigator.of(context).pop(date);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),*/
        );
      },
    );

    if (selectedDate != null) {
      _recordTraining(context, training, selectedDate);
    }
  }

  */