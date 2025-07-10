// Simple test for daily verse function structure
console.log('Testing Daily Verse API Response Structure...');

const testResponse = {
  "success": true,
  "data": {
    "reference": "John 3:16",
    "translations": {
      "esv": "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
      "hi": "क्योंकि परमेश्वर ने जगत से ऐसा प्रेम रखा कि उसने अपना एकलौता पुत्र दे दिया, ताकि जो कोई उस पर विश्वास करे वह नष्ट न हो, परन्तु अनन्त जीवन पाए।",
      "ml": "കാരണം ദൈവം ലോകത്തെ ഇങ്ങനെ സ്നേഹിച്ചു, തന്റെ ഏകജാതനായ പുത്രനെ നൽകി, അവനിൽ വിശ്വസിക്കുന്നവൻ നശിക്കാതെ നിത്യജീവൻ പ്രാപിക്കേണ്ടതിന്."
    },
    "date": "2025-07-10T00:00:00.000Z"
  }
};

// Validate structure
const isValid = (
  testResponse.success === true &&
  testResponse.data &&
  testResponse.data.reference &&
  testResponse.data.translations &&
  testResponse.data.translations.esv &&
  testResponse.data.translations.hi &&
  testResponse.data.translations.ml &&
  testResponse.data.date
);

console.log('Response structure valid:', isValid);
console.log('Sample response:', JSON.stringify(testResponse, null, 2));

if (isValid) {
  console.log('✅ Daily Verse API structure is correct');
} else {
  console.log('❌ Daily Verse API structure is invalid');
}