import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/models/product.dart';
import 'second_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Product>> _productsFuture;
  late Future<List> _categoriesFuture;
  late Future<List> _subCategoriesFuture;
  
  
final String baseUrl = 'https://flutter-ecommerce-app-production.up.railway.app/api/';
String get apiUrl => '${baseUrl}products/';

int? _selectedCategoryId; // category used for filtering products
int? _addProductCategoryId; // category selected when adding a product
  final productNameController = TextEditingController();
  final priceController = TextEditingController();
  final descriptionController = TextEditingController();
  final categoryController = TextEditingController();
  final subCategoryNameController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _productsFuture = _fetchProducts();
    _categoriesFuture = _fetchCategories();
    _subCategoriesFuture = _fetchSubCategories();
  }

  // FETCH PRODUCTS
  Future<List<Product>> _fetchProducts({int? categoryId}) async {
    try {
      Uri url;

      if (categoryId == null) {
        url = Uri.parse(apiUrl);
      } else {
        url = Uri.parse(apiUrl).replace(
          queryParameters: {
            'category': categoryId.toString(),
          },
        );
      }

      final response = await http.get(url);

      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);

        return jsonResponse
            .map((data) => Product.fromJson(data))
            .toList();
      } else {
        throw Exception("Failed to load products");
      }
    } catch (e) {
      throw Exception("Failed to load products: $e");
    }
  }

  // FETCH CATEGORIES
  Future<List> _fetchCategories() async {
    try {
      final response = await http.get(
        Uri.parse('${apiUrl}categories/'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception("Failed to load categories");
      }
    } catch (e) {
      throw Exception("Failed to load categories: $e");
    }
  }
  // FETCH SUB-CATEGORIES
  Future<List<dynamic>> _fetchSubCategories() async {
  try {
    final response = await http.get(
      Uri.parse('${apiUrl}subcategories/'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load sub-categories");
    }
  } catch (e) {
    throw Exception("Failed to load sub-categories: $e");
  }
}
//Add subcategories




  // ADD PRODUCT
  Future addProduct(
  String name,
  String price,
  String description,
  int? categoryId,
) async {
  final response = await http.post(
    Uri.parse(apiUrl),
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'name': name,
      'price': price,
      'description': description,
      'category': categoryId,
    }),
  );

  print(response.statusCode);
  print(response.body);

  if (response.statusCode != 200 && response.statusCode != 201) {
    throw Exception(
      "Failed to add product: ${response.statusCode}\n${response.body}",
    );
  }
}

  // ADD CATEGORY
  Future<void> addCategory(String name) async {
    final response = await http.post(
      Uri.parse('${apiUrl}categories/'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
      }),
    );

    print(response.statusCode);
    print(response.body);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add category');
    }
  }
Future addSubCategory(String name, int categoryId) async {
  final response = await http.post(
    Uri.parse('${apiUrl}subcategories/'),
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'name': name,
      'category': categoryId,
    }),
  );

  print("STATUS CODE: ${response.statusCode}");
  print("RESPONSE: ${response.body}");

  if (response.statusCode != 200 && response.statusCode != 201) {
    throw Exception(
      "Failed to add sub-category: ${response.statusCode}\n${response.body}",
    );
  }
}

  // REFRESH PRODUCTS
Future<void> _refreshProducts() async {
  final future = _fetchProducts(
    categoryId: _selectedCategoryId,
  );

  setState(() {
    _productsFuture = future;
  });

  await future;
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // DRAWER
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.blue,
              ),
              child: const Center(
                child: Text(
                  "Ecommerce App",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // PRODUCTS
            ExpansionTile(
              leading: const Icon(Icons.shopping_bag_rounded),
              title: const Text("Products"),
              children: [
                // ADD PRODUCTS
                ListTile(
                  leading: const Icon(Icons.shopping_bag_rounded),
                  title: const Text("Add Products"),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("Add Products"),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: productNameController,
                                decoration: const InputDecoration(
                                  labelText: "Product Name",
                                ),
                              ),
                              TextField(
                                controller: priceController,
                                decoration: const InputDecoration(
                                  labelText: "Price",
                                ),
                              ),
                              TextField(
                                controller: descriptionController,
                                decoration: const InputDecoration(
                                  labelText: "Description",
                                ),
                              ),
                              const SizedBox(height: 16),

FutureBuilder(
  future: _categoriesFuture,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const CircularProgressIndicator();
    }

    if (snapshot.hasError) {
      return Text(
        "Category Error: ${snapshot.error}",
      );
    }

    final categories = snapshot.data ?? [];

    return DropdownButtonFormField<int>(
      initialValue: _selectedCategoryId,
      decoration: const InputDecoration(
        labelText: "Select Category",
        border: OutlineInputBorder(),
      ),
      items: categories.map<DropdownMenuItem<int>>((category) {
        return DropdownMenuItem<int>(
          value: category['id'] as int,
          child: Text(category['name'].toString()),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _addProductCategoryId = value;
        });
      },
    );
  },
),
       ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text("Cancel"),
                            ),
ElevatedButton(
  onPressed: () async {
    await addProduct(
      productNameController.text,
      priceController.text,
      descriptionController.text,
      _addProductCategoryId,
    );

    productNameController.clear();
    priceController.clear();
    descriptionController.clear();

    Navigator.pop(context);

    await _refreshProducts();
  },
  child: const Text("Save"),
),
                          ],
                        );
                      },
                    );
                  },
                ),

                // LIST PRODUCTS
                ListTile(
                  leading: const Icon(Icons.shopping_bag_rounded),
                  title: const Text("List of Products"),
                  onTap: () {
                    Navigator.pop(context);
                    _refreshProducts();
                  },
                ),
              ],
            ),

            // CATEGORIES
            ExpansionTile(
              leading: const Icon(Icons.category),
              title: const Text("Categories"),
              children: [
                ListTile(
                  leading: const Icon(Icons.list_rounded),
                  title: const Text("Categories List"),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("Categories"),
                          content: FutureBuilder(
                            future: _categoriesFuture,
                            builder: (context, categorySnapshot) {
                              if (categorySnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox(
                                  height: 100,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              if (categorySnapshot.hasError) {
                                return Text("Error: ${categorySnapshot.error}");
                              }

                              final categories = categorySnapshot.data!;

                              if (categories.isEmpty) {
                                return const Text("No categories found");
                              }

                              return SizedBox(
                                width: double.maxFinite,
                                height: 300,
                                child: ListView.builder(
                                  itemCount: categories.length,
                                  itemBuilder: (context, index) {
                                    final category = categories[index];

                                    return ListTile(
                                      title: Text(category['name']),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () {
                                          print("Edit ${category['name']}");
                                        },
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.list_rounded),
                  title: const Text("Add Categories"),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("Add Categories"),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children:  [
                              TextField(
                                controller: categoryController,
                                decoration: const InputDecoration(
                                  labelText: "Category Name",
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: () async{
                                await addCategory(
                                  categoryController.text,
                                );
                                categoryController.clear();
                                setState(() {
                                  _categoriesFuture = _fetchCategories();
                                });
                                Navigator.pop(context);
                              },
                              child: const Text("Save"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),

            // SUB-CATEGORIES
// SUB-CATEGORIES
ExpansionTile(
  leading: const Icon(Icons.list_rounded),
  title: const Text("Sub-categories"),
  children: [

    // LIST SUB-CATEGORIES
    ListTile(
      leading: const Icon(Icons.list_rounded),
      title: const Text("Sub-categories List"),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("Sub-categories"),
              content: FutureBuilder<List>(
                future: _subCategoriesFuture,
                builder: (context, snapshot) {

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const SizedBox(
                      height: 100,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Text(
                      "Error: ${snapshot.error}",
                    );
                  }

                  final subCategories = snapshot.data!;

                  if (subCategories.isEmpty) {
                    return const Text(
                      "No sub-categories found",
                    );
                  }

                  return SizedBox(
                    width: double.maxFinite,
                    height: 300,
                    child: ListView.builder(
                      itemCount: subCategories.length,
                      itemBuilder: (context, index) {

                        final subCategory =
                            subCategories[index];

                        return ListTile(
                          title: Text(
                            subCategory['name'],
                          ),
                          subtitle: Text(
                            "Category: ${subCategory['category_name'] ?? 'Unknown'}",
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              print(
                                "Edit ${subCategory['name']}",
                              );
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    ),

    // ADD SUB-CATEGORY
    ListTile(
      leading: const Icon(Icons.add),
      title: const Text("Add Sub-categories"),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) {

            int? selectedCategoryId;

            return AlertDialog(
              title: const Text("Add Sub-category"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  TextField(
                    controller: subCategoryNameController,
                    decoration: const InputDecoration(
                      labelText: "Sub-category Name",
                    ),
                  ),

                  const SizedBox(height: 16),

                  FutureBuilder(
                    future: _categoriesFuture,
                    builder: (context, snapshot) {

                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }

                      if (snapshot.hasError) {
                        return Text(
                          "Error: ${snapshot.error}",
                        );
                      }

                      final categories = snapshot.data!;

                      return StatefulBuilder(
                        builder: (context, setDialogState) {

                          return DropdownButtonFormField<int>(
                            initialValue: selectedCategoryId,
                            decoration: const InputDecoration(
                              labelText: "Select Category",
                              border: OutlineInputBorder(),
                            ),
                            items: categories.map<DropdownMenuItem<int>>(
                              (category) {
                                return DropdownMenuItem<int>(
                                  value: category['id'],
                                  child: Text(
                                    category['name'],
                                  ),
                                );
                              },
                            ).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedCategoryId = value;
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),

              actions: [

                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),

                ElevatedButton(
                  onPressed: () async {

                    if (subCategoryNameController.text.isEmpty ||
                        selectedCategoryId == null) {
                      return;
                    }

                    await addSubCategory(
                      subCategoryNameController.text,
                      selectedCategoryId!,
                    );

                    subCategoryNameController.clear();

                    setState(() {
                      _subCategoriesFuture =
                          _fetchSubCategories();
                    });

                    Navigator.pop(context);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    ),
  ],
),
          ],
        ),
      ),
backgroundColor: Colors.grey[100],

      // APP BAR
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Products"),
        centerTitle: true,
      ),

      // BODY
      body: RefreshIndicator(
        onRefresh: _refreshProducts,
        child: FutureBuilder<List<Product>>(
          future: _productsFuture,
          builder: (context, snapshot) {
            // 1. LOADING
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            // 2. ERROR
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshProducts,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              );
            }

            // 3. EMPTY
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  "No products found in database.",
                ),
              );
            }

            // 4. SUCCESS
            final products = snapshot.data!;
            return ListView(
              padding:const EdgeInsets.all(16.0),
              children:[

                FutureBuilder(
                  future: _categoriesFuture,
                  builder: (context, categorySnapshot) {
                    if (categorySnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child:CircularProgressIndicator(),
                      );
                    }
                    
                    if(categorySnapshot.hasError){
                      return Text(
                        "Category Error: ${categorySnapshot.error}",
                      );
                    }
                    final categories=categorySnapshot.data!;
           return DropdownButtonFormField<int?>(
              initialValue: _selectedCategoryId,

              decoration: const InputDecoration(
                labelText: "Select Category",
                border: OutlineInputBorder(),
              ),
                    items:[
                      const DropdownMenuItem<int?>(
                        value:null,
                        child:Text("All Categories"),
                      ),

                      ...categories.map<DropdownMenuItem<int?>>(
                        (category){
                          return DropdownMenuItem<int?>(
                            value:category['id'],
                            child:Text(category['name']),
                            );
                          },
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                          _productsFuture = _fetchProducts(categoryId: value);
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                ...products.map((product) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Product Name: ${product.name}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 6),
                          Text(
                            "Price: \$${product.price}",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            "Description: ${product.description}",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {},
                              child: const Text("View Details"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),

      // FLOATING BUTTON
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SecondPage(),
            ),
          );
        },
        child: const Icon(Icons.arrow_forward),
      ),
    );
  }
}