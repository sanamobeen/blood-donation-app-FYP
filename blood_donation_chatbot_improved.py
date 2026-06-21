"""
Blood Donation Chatbot - Improved Version
Handles edge cases and provides better matching
"""

import pandas as pd
import re
import nltk
from nltk.corpus import stopwords
from nltk.stem import WordNetLemmatizer
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

# Download required NLTK data
try:
    nltk.data.find('corpora/stopwords')
except LookupError:
    nltk.download('stopwords')
    nltk.download('wordnet')
    nltk.download('omw-1.4')

class ImprovedBloodDonationChatbot:
    def __init__(self, faq_path='faq.csv'):
        """Initialize the chatbot with FAQ data"""
        # Load FAQ data
        self.faq = pd.read_csv(faq_path)
        self.questions = self.faq['question']
        self.answers = self.faq['answer']
        self.categories = self.faq['category']

        # Preprocessing setup
        self.stop_words = set(stopwords.words('english'))
        self.lemmatizer = WordNetLemmatizer()

        # Initialize vectorizer
        self.vectorizer = TfidfVectorizer()
        self.faq_vectors = None
        self._train()

    def preprocess(self, text):
        """Preprocess text for vectorization with lemmatization"""
        text = text.lower()
        text = re.sub(r'[^a-z0-9 ]', '', text)
        words = text.split()

        # Apply lemmatization to reduce words to root form
        filtered_words = [self.lemmatizer.lemmatize(w) for w in words if w not in self.stop_words]

        return ' '.join(filtered_words)

    def _train(self):
        """Train the vectorizer on FAQ questions"""
        self.faq_vectors = self.vectorizer.fit_transform(
            self.questions.apply(self.preprocess)
        )

    def _detect_category(self, text):
        """Detect the category of the question using keywords"""
        text_lower = text.lower()

        # Age-related keywords
        age_keywords = ['year', 'old', 'age', 'young', 'teenager', 'adult']
        if any(kw in text_lower for kw in age_keywords):
            return 'age'

        # Blood type keywords
        blood_types = ['a+', 'a-', 'b+', 'b-', 'ab+', 'ab-', 'o+', 'o-']
        if any(bt in text_lower for bt in blood_types):
            return 'blood_type'

        # Safety keywords
        safety_keywords = ['safe', 'risk', 'danger', 'pain', 'hurt']
        if any(kw in text_lower for kw in safety_keywords):
            return 'safety'

        # Frequency keywords
        frequency_keywords = ['often', 'frequent', 'again', 'repeat', 'interval']
        if any(kw in text_lower for kw in frequency_keywords):
            return 'frequency'

        # Food/eating keywords
        food_keywords = ['eat', 'drink', 'food', 'breakfast', 'meal', 'water']
        if any(kw in text_lower for kw in food_keywords):
            return 'food'

        return None

    def get_answer(self, user_question, top_k=3):
        """Get the best answer for a user question with category filtering"""
        processed_query = self.preprocess(user_question)

        # Detect category for better matching
        detected_category = self._detect_category(user_question)

        # Filter by category if detected
        if detected_category:
            category_map = {
                'age': 'eligibility_requirements',
                'blood_type': 'blood_type_compatibility',
                'safety': 'safety_risks',
                'frequency': 'donation_frequency_limits',
                'food': 'preparation_for_donation'
            }

            target_category = category_map.get(detected_category)
            if target_category:
                # Get filtered indices
                filtered_indices = self.faq[self.faq['category'] == target_category].index

                if len(filtered_indices) > 0:
                    # Vectorize filtered questions only
                    filtered_vectors = self.faq_vectors[filtered_indices]
                    query_vector = self.vectorizer.transform([processed_query])

                    # Calculate similarities on filtered set
                    similarities = cosine_similarity(query_vector, filtered_vectors).flatten()

                    # Get best match from filtered set
                    best_idx = similarities.argmax()
                    original_idx = filtered_indices[best_idx]

                    return [{
                        'question': self.questions.iloc[original_idx],
                        'answer': self.answers.iloc[original_idx],
                        'category': self.categories.iloc[original_idx],
                        'confidence': float(similarities[best_idx])
                    }]

        # Fallback to full search
        query_vector = self.vectorizer.transform([processed_query])
        similarities = cosine_similarity(query_vector, self.faq_vectors).flatten()

        # Get top k matches
        top_indices = similarities.argsort()[-top_k:][::-1]

        results = []
        for idx in top_indices:
            results.append({
                'question': self.questions.iloc[idx],
                'answer': self.answers.iloc[idx],
                'category': self.categories.iloc[idx],
                'confidence': float(similarities[idx])
            })

        return results

    def chat(self, user_question):
        """Simple chat interface - returns best answer"""
        results = self.get_answer(user_question, top_k=1)

        if results and results[0]['confidence'] > 0.1:
            return {
                'answer': results[0]['answer'],
                'confidence': results[0]['confidence'],
                'category': results[0]['category'],
                'matched_question': results[0]['question']
            }
        else:
            return {
                'answer': "I'm not sure about that. Can you try rephrasing your question about blood donation?",
                'confidence': 0.0,
                'category': None,
                'matched_question': None
            }


# Example usage
if __name__ == "__main__":
    # Initialize improved chatbot
    bot = ImprovedBloodDonationChatbot()

    # Test questions
    test_questions = [
        "Can a 19 year old donate blood?",
        "Who can donate to A+?",
        "Is blood donation safe?",
        "How often can I donate blood?",
        "What should I eat before donating?",
        "What is the minimum age?"
    ]

    print("Blood Donation Chatbot - Improved Version")
    print("=" * 60)

    for question in test_questions:
        result = bot.chat(question)
        print(f"\nQ: {question}")
        print(f"A: {result['answer'][:100]}...")
        print(f"Confidence: {result['confidence']:.2f}")
        print(f"Category: {result['category']}")
        print(f"Matched: {result['matched_question']}")
        print("-" * 60)
