import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final app = CatFactsApp();
  await app.loadFavorites();
  await app.start();
}

class CatFactsApp {
  final List<Map<String, dynamic>> favoriteFacts = [];
  final String favoritesFilePath = 'favorites.json';
  final Map<String, String> supportedLanguages = {
    '1': 'en', 
    '2': 'es',
    '3': 'fr',
    '4': 'de',
    '5': 'it',
  };

  final String deeplApiKey = '59a0b7c0-778a-4fb9-ac11-f39087262bf1:fx';
  final String deeplApiUrl = 'https://api-free.deepl.com/v2/translate';

  Future<void> loadFavorites() async {
    final file = File(favoritesFilePath);
    
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        
        favoriteFacts.clear();
        for (var item in jsonList) {
          favoriteFacts.add(Map<String, dynamic>.from(item));
        }
        
        print('Loaded ${favoriteFacts.length} favorite facts.');
      } catch (e) {
        print('Error loading favorites: $e');
      }
    } else {
      print('No favorites file found. Creating new list.');
    }
  }

  Future<void> saveFavorites() async {
    final file = File(favoritesFilePath);
    
    try {
      final jsonString = json.encode(favoriteFacts);
      await file.writeAsString(jsonString);
      print('Favorites saved successfully.');
    } catch (e) {
      print('Error saving favorites: $e');
    }
  }

  Future<void> start() async {
    print('=== Cat Facts App ===\n');
    
    bool isRunning = true;
    while (isRunning) {
      displayMainMenu();
      final choice = stdin.readLineSync()?.trim() ?? '';
      
      switch (choice) {
        case '1':
          await showRandomFact();
          break;
        case '2':
          showFavoritesList();
          break;
        case '3':
          await clearFavoritesList();
          break;
        case '4':
          await saveFavorites();
          isRunning = false;
          print('Goodbye!');
          break;
        default:
          print('Invalid option. Please try again.');
      }
    }
  }

  void displayMainMenu() {
    print('\n=== Main Menu ===');
    print('1. Show a random cat fact');
    print('2. Show my favorite facts');
    print('3. Clear my favorite facts');
    print('4. Exit');
    print('Enter your choice (1-4): ');
  }

  Future<void> showRandomFact() async {
    final String languageCode = await selectLanguage();
    if (languageCode.isEmpty) return;
    
    try {
      final factData = await fetchCatFact();
      
      if (languageCode == 'en') {
        print('\n=== Random Cat Fact ===');
        print(factData['fact']);
        print('Length: ${factData['length']}');
        
        final fact = factData;
        
        await handleFactOptions(fact);
      } else {
        print('\nTranslating fact to ${getLanguageName(languageCode)}...');
        
        try {
          final translatedFact = await translateTextWithDeepL(
            factData['fact'],
            languageCode
          );
          
          final translatedFactData = {
            'fact': translatedFact,
            'length': translatedFact.length,
            'original': factData['fact'],
            'language': languageCode
          };
          
          print('\n=== Random Cat Fact ===');
          print(translatedFact);
          print('Length: ${translatedFact.length}');
          
          await handleFactOptions(translatedFactData);
        } catch (e) {
          print('Translation error: $e');
          print('Showing original fact in English:');
          print(factData['fact']);
          
          final fact = factData;
          
          await handleFactOptions(fact);
        }
      }
    } catch (e) {
      print('Error fetching cat fact: $e');
    }
  }

  Future<String> selectLanguage() async {
    print('\n=== Select Language ===');
    supportedLanguages.forEach((key, value) {
      final langName = getLanguageName(value);
      print('$key. $langName');
    });
    print('Enter your choice or press Enter to go back: ');
    
    final choice = stdin.readLineSync()?.trim() ?? '';
    if (choice.isEmpty) return '';
    
    return supportedLanguages[choice] ?? '';
  }

  String getLanguageName(String code) {
    switch (code) {
      case 'en': return 'English';
      case 'es': return 'Spanish (Español)';
      case 'fr': return 'French (Français)';
      case 'de': return 'German (Deutsch)';
      case 'it': return 'Italian (Italiano)';
      default: return 'Unknown';
    }
  }

  Future<Map<String, dynamic>> fetchCatFact() async {
    final url = Uri.parse('https://catfact.ninja/fact');
    
    final response = await http.get(url, headers: {
      'Accept': 'application/json',
    });
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load cat fact: ${response.statusCode}');
    }
  }
  
  Future<String> translateTextWithDeepL(String text, String targetLanguage) async {
  final url = Uri.parse(deeplApiUrl);
  
  final Map<String, String> requestBody = {
    'text': text,
    'target_lang': targetLanguage.toUpperCase(),
    'auth_key': deeplApiKey,
  };
  
  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: requestBody,
  );
  
  if (response.statusCode == 200) {
    try {
      final Map<String, dynamic> data = json.decode(response.body);
      
      if (data.containsKey('translations') && data['translations'].isNotEmpty) {
        return data['translations'][0]['text'] as String;
      } else {
        print('No translations found in the response: $data');
        throw Exception('Translation failed: No translations found.');
      }
    } catch (e) {
      print('Error parsing response: $e');
      throw Exception('Translation failed: Unable to parse response.');
    }
  } else {
    print('Error response: ${response.body}');
    throw Exception('Translation failed: ${response.statusCode}');
  }
}

  Future<void> handleFactOptions(Map<String, dynamic> fact) async {
    print('\nOptions:');
    print('1. Add to favorites and show next fact');
    print('2. Show next fact');
    print('3. Show my favorite facts');
    print('4. Return to main menu');
    print('Enter your choice (1-4): ');
    
    final choice = stdin.readLineSync()?.trim() ?? '';
    
    switch (choice) {
      case '1':
        addToFavorites(fact);
        await saveFavorites();
        await showRandomFact();
        break;
      case '2':
        await showRandomFact();
        break;
      case '3':
        showFavoritesList();
        break;
      case '4':
        return;
      default:
        print('Invalid option. Returning to main menu.');
    }
  }

  void addToFavorites(Map<String, dynamic> fact) {
    final favorite = fact;
    
    bool isDuplicate = favoriteFacts.any((item) => 
        item['fact'] == fact['fact'] || 
        (fact.containsKey('original') && item.containsKey('original') && item['original'] == fact['original'])
    );
    
    if (isDuplicate) {
      print('This fact is already in your favorites!');
    } else {
      favoriteFacts.add(favorite);
      print('Fact added to favorites!');
    }
  }

  void showFavoritesList() {
    print('\n=== My Favorite Cat Facts ===');
    
    if (favoriteFacts.isEmpty) {
      print('Your favorites list is empty. Add some facts first!');
      return;
    }
    
    for (int i = 0; i < favoriteFacts.length; i++) {
      final fact = favoriteFacts[i];
      print('${i + 1}. ${fact['fact']}');
      
      if (fact.containsKey('original') && fact['original'] != fact['fact']) {
        print('   Original (English): ${fact['original']}');
      }
      
      if (fact.containsKey('language')) {
        print('   Language: ${getLanguageName(fact['language'])}');
      }
      print('   Length: ${fact['length']}\n');
    }
    
    print('Total favorites: ${favoriteFacts.length}\n');
  }

  Future<void> clearFavoritesList() async {
    if (favoriteFacts.isEmpty) {
      print('Your favorites list is already empty.');
      return;
    }
    
    print('\nAre you sure you want to clear your favorites list? (y/n): ');
    final confirmation = stdin.readLineSync()?.toLowerCase() ?? '';
    
    if (confirmation == 'y' || confirmation == 'yes') {
      favoriteFacts.clear();
      await saveFavorites();
      print('Favorites list cleared successfully!');
    } else {
      print('Operation cancelled. Your favorites list remains unchanged.');
    }
  }
}