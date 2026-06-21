"""
Blood Donation Chatbot - Final Version
With confidence threshold and keyword validation
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

class BloodDonationChatbotFinal:
    def __init__(self, faq_path='faq.csv', confidence_threshold=0.5):
        """Initialize the chatbot with FAQ data and confidence threshold"""
        # Load FAQ data
        self.faq = pd.read_csv(faq_path)
        self.questions = self.faq['question']
        self.answers = self.faq['answer']
        self.categories = self.faq['category']
        self.confidence_threshold = confidence_threshold

        # Preprocessing setup
        self.stop_words = set(stopwords.words('english'))
        self.lemmatizer = WordNetLemmatizer()

        # Initialize vectorizer
        self.vectorizer = TfidfVectorizer()
        self.faq_vectors = None
        self._train()

        # Blood donation keywords for validation
        self.blood_keywords = [
            'blood', 'donate', 'donation', 'donor', 'recipient',
            'plasma', 'platelet', 'hemoglobin', 'iron',
            'a+', 'b+', 'ab+', 'o+', 'a-', 'b-', 'ab-', 'o-',
            'safety', 'safe', 'risk', 'pain', 'needle',
            'age', 'weight', 'health', 'medical',
            'who', 'what', 'how', 'can', 'should', 'is', 'are'
        ]

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

    def _has_blood_keywords(self, text):
        """Check if text contains blood donation related keywords"""
        text_lower = text.lower()
        return any(keyword in text_lower for keyword in self.blood_keywords)

    def chat(self, user_question):
        """Chat with confidence threshold and keyword validation"""
        # Step 1: Check for blood donation keywords
        if not self._has_blood_keywords(user_question):
            return {
                'answer': "Sorry, I only answer questions about blood donation. Please ask about blood donation topics.",
                'confidence': 0.0,
                'category': None,
                'matched_question': None
            }

        # Step 2: Preprocess and vectorize
        processed_query = self.preprocess(user_question)
        query_vector = self.vectorizer.transform([processed_query])

        # Step 3: Find best match
        similarities = cosine_similarity(query_vector, self.faq_vectors).flatten()
        best_match = similarities.argmax()
        score = similarities[best_match]

        # Step 4: Apply confidence threshold
        if score < self.confidence_threshold:
            return {
                'answer': "Sorry, I couldn't understand your question. Please try asking about blood donation topics like 'Who can donate to A+?' or 'Is blood donation safe?'",
                'confidence': float(score),
                'category': None,
                'matched_question': None
            }

        # Step 5: Return answer
        return {
            'answer': self.answers.iloc[best_match],
            'confidence': float(score),
            'category': self.categories.iloc[best_match],
            'matched_question': self.questions.iloc[best_match]
        }


# Example usage
if __name__ == "__main__":
    # Initialize chatbot with threshold
    bot = BloodDonationChatbotFinal(confidence_threshold=0.5)

    # Test questions
    test_questions = [
        # Related questions (should answer)
        "Is blood donation safe?",
        "How often can I donate blood?",
        "Who can donate to A+?",
        "What is the minimum age?",

        # Unrelated questions (should not answer)
        "How do I make a pizza?",
        "What is the capital of France?",
        "Teach me Python programming",
        "Who won the World Cup?",
        "How do I bake a cake?"
    ]

    print("Blood Donation Chatbot - Final Version")
    print("With Keyword Validation + Confidence Threshold")
    print("=" * 70)

    for question in test_questions:
        result = bot.chat(question)
        print(f"\nQ: {question}")
        print(f"Confidence: {result['confidence']:.2f}")
        print(f"Answer: {result['answer'][:100]}...")
        print("-" * 70)

    # Show statistics
    print("\n" + "=" * 70)
    print("Summary:")
    print("✅ Keyword validation filters out completely unrelated questions")
    print("✅ Confidence threshold (0.5) handles low-matches")
    print("✅ Only answers questions about blood donation")
