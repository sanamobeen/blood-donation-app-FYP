"""
Blood Donation Chatbot - Interactive Command Line Interface
Run this file to start chatting with the bot!
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
    nltk.download('punkt')
    nltk.download('wordnet')
    nltk.download('omw-1.4')

class BloodDonationChatbot:
    """Interactive blood donation chatbot"""

    def __init__(self, faq_path='faq.csv', confidence_threshold=0.5):
        """Initialize the chatbot"""
        print("Initializing Blood Donation Chatbot...")

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

        # Blood donation keywords (removed common question words)
        self.blood_keywords = [
            'blood', 'donate', 'donation', 'donor', 'recipient',
            'plasma', 'platelet', 'hemoglobin', 'iron',
            'a+', 'b+', 'ab+', 'o+', 'a-', 'b-', 'ab-', 'o-',
            'safety', 'safe', 'risk', 'pain', 'needle',
            'age', 'weight', 'health', 'medical',
            'eligible', 'eligibility', 'requirement', 'requirements',
            'frequency', 'often', 'interval', 'period',
            'type', 'compatibility', 'match', 'matching',
            'test', 'testing', 'screen', 'screening',
            'center', 'bank', 'camp', 'drive',
            'process', 'procedure', 'prepare', 'preparation',
            'benefit', 'benefits', 'effect', 'effects',
            'eat', 'drink', 'food', 'water', 'meal',
            'after', 'before', 'care', 'recovery',
            'deferral', 'defer', 'disqualif'
        ]

        print(f"[OK] Loaded {len(self.questions)} FAQ entries")
        print(f"[OK] Confidence threshold: {self.confidence_threshold}")
        print(f"[OK] Ready to chat!\n")

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

    def get_answer(self, user_question):
        """Get answer for user question"""
        # Step 1: Check for blood donation keywords
        if not self._has_blood_keywords(user_question):
            return "[ERROR] Sorry, I only answer questions about blood donation. Please ask about blood donation topics."

        # Step 2: Preprocess and vectorize
        processed_query = self.preprocess(user_question)
        query_vector = self.vectorizer.transform([processed_query])

        # Step 3: Find best match
        similarities = cosine_similarity(query_vector, self.faq_vectors).flatten()
        best_match = similarities.argmax()
        score = similarities[best_match]

        # Step 4: Apply confidence threshold
        if score < self.confidence_threshold:
            return f"[?] I'm not sure about that (confidence: {score:.2f}). Please try rephrasing your question about blood donation."

        # Step 5: Return answer
        matched_question = self.questions.iloc[best_match]
        answer = self.answers.iloc[best_match]
        category = self.categories.iloc[best_match]

        return f"[OK] [{category}] {answer}"

    def show_help(self):
        """Show help message"""
        print("\n" + "="*60)
        print("Blood Donation Chatbot - Help")
        print("="*60)
        print("\nYou can ask me about:")
        print("  • Blood type compatibility (e.g., 'Who can donate to A+?')")
        print("  • Eligibility (e.g., 'Can a diabetic donate?')")
        print("  • Donation process (e.g., 'Does it hurt?')")
        print("  • Safety (e.g., 'Is blood donation safe?')")
        print("  • Frequency (e.g., 'How often can I donate?')")
        print("  • Preparation (e.g., 'What should I eat?')")
        print("  • And much more!")
        print("\nCommands:")
        print("  'help' - Show this help message")
        print("  'exit' or 'quit' - Exit the chatbot")
        print("  'stats' - Show chatbot statistics")
        print("\n" + "="*60 + "\n")

    def show_stats(self):
        """Show chatbot statistics"""
        print("\n" + "="*60)
        print("Chatbot Statistics")
        print("="*60)
        print(f"Total FAQ entries: {len(self.questions)}")
        print(f"Number of categories: {self.categories.nunique()}")
        print(f"Confidence threshold: {self.confidence_threshold}")
        print("\nTop 5 categories:")
        category_counts = self.categories.value_counts().head()
        for cat, count in category_counts.items():
            print(f"  • {cat}: {count} questions")
        print("="*60 + "\n")


def main():
    """Main chatbot loop"""
    print("\n" + "="*60)
    print("Blood Donation Chatbot")
    print("="*60)
    print("Type 'help' for commands, 'exit' to quit")
    print("="*60 + "\n")

    # Initialize chatbot
    bot = BloodDonationChatbot(confidence_threshold=0.5)

    # Main loop
    while True:
        try:
            # Get user input
            question = input("You: ").strip()

            # Skip empty input
            if not question:
                continue

            # Handle commands
            if question.lower() in ['exit', 'quit']:
                print("\nThank you for using the Blood Donation Chatbot!")
                print("Save lives by donating blood!\n")
                break

            if question.lower() == 'help':
                bot.show_help()
                continue

            if question.lower() == 'stats':
                bot.show_stats()
                continue

            # Get response
            response = bot.get_answer(question)
            print(f"Bot: {response}\n")

        except KeyboardInterrupt:
            print("\n\nExiting chatbot. Goodbye!")
            break
        except Exception as e:
            print(f"Bot: [ERROR] An error occurred: {e}")
            print("Please try again.\n")


if __name__ == "__main__":
    main()
