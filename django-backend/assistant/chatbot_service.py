"""
AI Chatbot Service with TF-IDF and Lemmatization.

Implements the RAG-based chatbot for blood donation FAQ.
"""
import re
import pickle
import os
from typing import List, Dict, Optional
import pandas as pd
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
    """
    Blood Donation Chatbot with TF-IDF and Lemmatization.

    Matches user questions to FAQ entries using vector similarity.
    """

    # Blood donation keywords for validation
    BLOOD_KEYWORDS = [
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

    def __init__(self, confidence_threshold=0.3):
        """Initialize the chatbot with confidence threshold."""
        self.confidence_threshold = confidence_threshold
        self.stop_words = set(stopwords.words('english'))
        self.lemmatizer = WordNetLemmatizer()
        self.vectorizer = TfidfVectorizer()
        self.faq_vectors = None
        self.faq_data = None
        # Role-specific FAQ data
        self.donor_faq_data = None
        self.donor_faq_vectors = None
        self.patient_faq_data = None
        self.patient_faq_vectors = None
        self._load_from_db()

    def _load_from_db(self, target_role='both'):
        """Load FAQ data from database filtered by target role."""
        from .models import FAQ

        # Filter FAQs by target role
        if target_role == 'donor':
            faqs = FAQ.objects.filter(
                is_active=True,
                target_role__in=['both', 'donor']
            ).order_by('-priority', 'category')
        elif target_role == 'patient':
            faqs = FAQ.objects.filter(
                is_active=True,
                target_role__in=['both', 'patient']
            ).order_by('-priority', 'category')
        else:
            # Load all active FAQs
            faqs = FAQ.objects.filter(is_active=True).order_by('-priority', 'category')

        if not faqs.exists():
            print(f"[WARNING] No active FAQs found for role: {target_role}")
            return

        # Prepare FAQ data
        faq_data = []
        for faq in faqs:
            faq_data.append({
                'id': str(faq.id),
                'question': faq.question,
                'answer': faq.answer,
                'category': faq.category,
                'keywords': faq.keywords or '',
                'target_role': faq.target_role
            })

        # Train vectorizer
        questions = [faq['question'] for faq in faq_data]
        faq_vectors = self.vectorizer.fit_transform(
            [self.preprocess(q) for q in questions]
        )

        # Store based on role
        if target_role == 'donor':
            self.donor_faq_data = faq_data
            self.donor_faq_vectors = faq_vectors
            print(f"[OK] Loaded {len(faq_data)} FAQ entries for donors")
        elif target_role == 'patient':
            self.patient_faq_data = faq_data
            self.patient_faq_vectors = faq_vectors
            print(f"[OK] Loaded {len(faq_data)} FAQ entries for patients")
        else:
            self.faq_data = faq_data
            self.faq_vectors = faq_vectors
            print(f"[OK] Loaded {len(faq_data)} FAQ entries (all)")

    def load_role_specific_faqs(self):
        """Load role-specific FAQ data for donors and patients."""
        self._load_from_db('donor')
        self._load_from_db('patient')
        # Also load general FAQs as fallback
        if not self.faq_data:
            self._load_from_db('both')

    def preprocess(self, text: str) -> str:
        """
        Preprocess text for vectorization with lemmatization.

        Args:
            text: Input text to preprocess

        Returns:
            Preprocessed text string
        """
        text = text.lower()
        text = re.sub(r'[^a-z0-9 ]', '', text)
        words = text.split()

        # Apply lemmatization to reduce words to root form
        filtered_words = [
            self.lemmatizer.lemmatize(w)
            for w in words
            if w not in self.stop_words and len(w) > 1
        ]

        return ' '.join(filtered_words)

    def _has_blood_keywords(self, text: str) -> bool:
        """Check if text contains blood donation related keywords."""
        text_lower = text.lower()
        return any(keyword in text_lower for keyword in self.BLOOD_KEYWORDS)

    def _detect_category(self, text: str) -> Optional[str]:
        """Detect the category of the question using keywords."""
        text_lower = text.lower()

        # Age-related keywords
        age_keywords = ['year', 'old', 'age', 'young', 'teenager', 'adult']
        if any(kw in text_lower for kw in age_keywords):
            return 'eligibility_requirements'

        # Blood type keywords
        blood_types = ['a+', 'a-', 'b+', 'b-', 'ab+', 'ab-', 'o+', 'o-']
        if any(bt in text_lower for bt in blood_types):
            return 'blood_type_compatibility'

        # Safety keywords
        safety_keywords = ['safe', 'risk', 'danger', 'pain', 'hurt']
        if any(kw in text_lower for kw in safety_keywords):
            return 'safety_risks'

        # Frequency keywords
        frequency_keywords = ['often', 'frequent', 'again', 'repeat', 'interval']
        if any(kw in text_lower for kw in frequency_keywords):
            return 'donation_frequency_limits'

        # Food/eating keywords
        food_keywords = ['eat', 'drink', 'food', 'breakfast', 'meal', 'water']
        if any(kw in text_lower for kw in food_keywords):
            return 'preparation_for_donation'

        return None

    def get_answer(self, user_question: str, user_role: str = 'both', top_k: int = 3) -> Dict:
        """
        Get the best answer for a user question.

        Args:
            user_question: The user's question
            user_role: User's role ('donor', 'patient', or 'both')
            top_k: Number of top matches to return

        Returns:
            Dict with answer, confidence, category, and matched_question
        """
        # Select appropriate FAQ data based on user role
        faq_data = self.faq_data
        faq_vectors = self.faq_vectors

        if user_role == 'donor' and self.donor_faq_data:
            faq_data = self.donor_faq_data
            faq_vectors = self.donor_faq_vectors
        elif user_role == 'patient' and self.patient_faq_data:
            faq_data = self.patient_faq_data
            faq_vectors = self.patient_faq_vectors

        if not faq_data or faq_vectors is None:
            return {
                'answer': "Sorry, the FAQ database is not available. Please try again later.",
                'confidence': 0.0,
                'category': None,
                'matched_question': None
            }

        # Detect category for better matching
        detected_category = self._detect_category(user_question)

        # Preprocess question
        processed_query = self.preprocess(user_question)
        query_vector = self.vectorizer.transform([processed_query])

        # If category detected, filter by category first
        if detected_category:
            category_indices = [
                i for i, faq in enumerate(faq_data)
                if faq['category'] == detected_category
            ]

            if category_indices:
                # Get vectors for filtered category
                filtered_vectors = faq_vectors[category_indices]
                similarities = cosine_similarity(query_vector, filtered_vectors).flatten()

                # Get best match
                best_idx = similarities.argmax()
                score = similarities[best_idx]
                original_idx = category_indices[best_idx]

                if score >= self.confidence_threshold:
                    matched_faq = faq_data[original_idx]
                    return {
                        'answer': matched_faq['answer'],
                        'confidence': float(score),
                        'category': matched_faq['category'],
                        'matched_question': matched_faq['question'],
                        'faq_id': matched_faq['id']
                    }

        # Fallback to full search
        similarities = cosine_similarity(query_vector, faq_vectors).flatten()
        best_match = similarities.argmax()
        score = similarities[best_match]

        if score < self.confidence_threshold:
            return {
                'answer': "Sorry, I couldn't understand your question. Please try asking about blood donation topics like 'Who can donate to A+?' or 'Is blood donation safe?'",
                'confidence': float(score),
                'category': None,
                'matched_question': None
            }

        matched_faq = faq_data[best_match]
        return {
            'answer': matched_faq['answer'],
            'confidence': float(score),
            'category': matched_faq['category'],
            'matched_question': matched_faq['question'],
            'faq_id': matched_faq['id']
        }

    def reload_faq(self):
        """Reload FAQ data from database (call after updating FAQs)."""
        # Load all FAQs
        self._load_from_db('both')
        # Load role-specific FAQs
        self.load_role_specific_faqs()


# Global chatbot instance (will be initialized on first use)
_chatbot_instance = None


def get_chatbot():
    """Get or create the global chatbot instance."""
    global _chatbot_instance
    if _chatbot_instance is None:
        _chatbot_instance = BloodDonationChatbot()
    return _chatbot_instance


def reload_chatbot():
    """Reload the chatbot with fresh data from database."""
    global _chatbot_instance
    _chatbot_instance = BloodDonationChatbot()
    return _chatbot_instance
