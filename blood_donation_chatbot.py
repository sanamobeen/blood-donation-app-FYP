"""
Blood Donation Chatbot
Simple RAG implementation using TF-IDF and Cosine Similarity
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

class BloodDonationChatbot:
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

    def get_answer(self, user_question, top_k=3):
        """Get the best answer for a user question"""
        # Preprocess and vectorize user question
        processed_query = self.preprocess(user_question)
        query_vector = self.vectorizer.transform([processed_query])

        # Calculate similarities
        similarities = cosine_similarity(query_vector, self.faq_vectors).flatten()

        # Get top k matches
        top_indices = similarities.argsort()[-top_k:][::-1]

        # Prepare results
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

        if results and results[0]['confidence'] > 0.2:
            return {
                'answer': results[0]['answer'],
                'confidence': results[0]['confidence'],
                'category': results[0]['category']
            }
        else:
            return {
                'answer': "I'm not sure about that. Can you try rephrasing your question about blood donation?",
                'confidence': 0.0,
                'category': None
            }

    def chat_with_details(self, user_question, top_k=3):
        """Chat with multiple options and details"""
        results = self.get_answer(user_question, top_k=top_k)

        response = {
            'query': user_question,
            'matches': results,
            'total_matches': len(results)
        }

        return response


# Example usage
if __name__ == "__main__":
    # Initialize chatbot
    bot = BloodDonationChatbot()

    # Test questions
    test_questions = [
        "Can a 19 year old donate blood?",
        "Who can donate to A+?",
        "Is blood donation safe?",
        "How often can I donate blood?",
        "What should I eat before donating?"
    ]

    print("Blood Donation Chatbot")
    print("=" * 60)

    for question in test_questions:
        result = bot.chat(question)
        print(f"\nQ: {question}")
        print(f"A: {result['answer'][:100]}...")
        print(f"Confidence: {result['confidence']:.2f}")
        print(f"Category: {result['category']}")
        print("-" * 60)
