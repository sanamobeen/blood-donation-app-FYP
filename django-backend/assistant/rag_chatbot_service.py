"""
TRUE RAG Chatbot Service with LLM Generation

This module implements true Retrieval-Augmented Generation:
1. RETRIEVAL: Use TF-IDF to find relevant FAQs
2. AUGMENTATION: Pass retrieved FAQs as context to LLM
3. GENERATION: LLM generates a contextual response

Requirements:
    - openai (for GPT-4) or anthropic (for Claude)
    - or use Ollama for local LLMs (free)
"""

import os
import re
from typing import Dict, List, Optional
import pandas as pd
import nltk
from nltk.corpus import stopwords
from nltk.stem import WordNetLemmatizer
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

# Try to import LLM providers (all optional)
try:
    import openai
    OPENAI_AVAILABLE = True
except ImportError:
    OPENAI_AVAILABLE = False

try:
    import anthropic
    ANTHROPIC_AVAILABLE = True
except ImportError:
    ANTHROPIC_AVAILABLE = False


class TrueRAGChatbot:
    """
    True RAG Chatbot with LLM Generation.

    Combines:
    - TF-IDF retrieval for finding relevant FAQs
    - LLM generation for contextual responses
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

    def __init__(
        self,
        confidence_threshold=0.2,  # Lower threshold for RAG (we'll use LLM to handle lower matches)
        top_k=3,  # Number of FAQs to retrieve for context
        llm_provider='openai',  # 'openai', 'anthropic', or 'ollama'
        llm_model='gpt-4o-mini',  # Model to use
        temperature=0.3  # Lower temperature for more factual responses
    ):
        """Initialize the True RAG Chatbot"""
        self.confidence_threshold = confidence_threshold
        self.top_k = top_k
        self.llm_provider = llm_provider
        self.llm_model = llm_model
        self.temperature = temperature

        # Initialize NLP components
        self.stop_words = set(stopwords.words('english'))
        self.lemmatizer = WordNetLemmatizer()
        self.vectorizer = TfidfVectorizer()

        # FAQ data
        self.faq_data = None
        self.faq_vectors = None
        self.donor_faq_data = None
        self.patient_faq_data = None

        # Load FAQs from database
        self._load_from_db()

        # Configure LLM
        self._configure_llm()

    def _configure_llm(self):
        """Configure the LLM provider"""
        if self.llm_provider == 'openai':
            if not OPENAI_AVAILABLE:
                raise ImportError("OpenAI library not installed. Run: pip install openai")
            api_key = os.environ.get('OPENAI_API_KEY')
            if not api_key:
                raise ValueError("OPENAI_API_KEY environment variable not set")
            self.client = openai.OpenAI(api_key=api_key)

        elif self.llm_provider == 'anthropic':
            if not ANTHROPIC_AVAILABLE:
                raise ImportError("Anthropic library not installed. Run: pip install anthropic")
            api_key = os.environ.get('ANTHROPIC_API_KEY')
            if not api_key:
                raise ValueError("ANTHROPIC_API_KEY environment variable not set")
            self.client = anthropic.Anthropic(api_key=api_key)

        elif self.llm_provider == 'ollama':
            # Ollama is free and runs locally
            try:
                import requests
                self.ollama_base_url = os.environ.get('OLLAMA_BASE_URL', 'http://localhost:11434')
                # Test connection
                response = requests.get(f"{self.ollama_base_url}/api/tags", timeout=2)
                if response.status_code != 200:
                    raise ConnectionError("Cannot connect to Ollama. Make sure Ollama is running.")
            except ImportError:
                raise ImportError("Requests library not installed. Run: pip install requests")
            except Exception as e:
                raise ConnectionError(f"Cannot connect to Ollama: {e}")

    def _load_from_db(self, target_role='both'):
        """Load FAQ data from database filtered by target role"""
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
        """Load role-specific FAQ data for donors and patients"""
        self._load_from_db('donor')
        self._load_from_db('patient')
        if not self.faq_data:
            self._load_from_db('both')

    def preprocess(self, text: str) -> str:
        """Preprocess text for vectorization with lemmatization"""
        text = text.lower()
        text = re.sub(r'[^a-z0-9 ]', '', text)
        words = text.split()

        filtered_words = [
            self.lemmatizer.lemmatize(w)
            for w in words
            if w not in self.stop_words and len(w) > 1
        ]

        return ' '.join(filtered_words)

    def _retrieve_relevant_faqs(self, user_question: str, user_role: str = 'both') -> List[Dict]:
        """
        RETRIEVAL STEP: Find top-K most relevant FAQs using TF-IDF

        Args:
            user_question: The user's question
            user_role: User's role for filtering

        Returns:
            List of top-K relevant FAQs with their similarity scores
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
            return []

        # Preprocess question
        processed_query = self.preprocess(user_question)
        query_vector = self.vectorizer.transform([processed_query])

        # Calculate cosine similarity
        similarities = cosine_similarity(query_vector, faq_vectors).flatten()

        # Get top-K results
        top_k_indices = similarities.argsort()[-self.top_k:][::-1]

        relevant_faqs = []
        for idx in top_k_indices:
            if similarities[idx] > 0:  # Only include if there's some similarity
                relevant_faqs.append({
                    'faq': faq_data[idx],
                    'similarity': float(similarities[idx])
                })

        return relevant_faqs

    def _build_context(self, relevant_faqs: List[Dict]) -> str:
        """
        Build context string from retrieved FAQs

        Args:
            relevant_faqs: List of relevant FAQs with similarity scores

        Returns:
            Formatted context string for LLM
        """
        if not relevant_faqs:
            return "No specific information found in the knowledge base."

        context_parts = []
        for i, item in enumerate(relevant_faqs, 1):
            faq = item['faq']
            similarity = item['similarity']
            context_parts.append(
                f"Source {i} (Relevance: {similarity:.2f}):\n"
                f"Q: {faq['question']}\n"
                f"A: {faq['answer']}\n"
                f"Category: {faq.get('category', 'N/A')}\n"
            )

        return "\n".join(context_parts)

    def _generate_with_llm(self, user_question: str, context: str, user_role: str) -> str:
        """
        GENERATION STEP: Use LLM to generate response based on context

        Args:
            user_question: The user's original question
            context: Retrieved FAQ context
            user_role: User's role for persona

        Returns:
            Generated response from LLM
        """
        # Build system prompt based on role
        role_persona = {
            'donor': "You are a helpful blood donation assistant speaking with a potential donor.",
            'patient': "You are a helpful blood donation assistant speaking with a patient or family member seeking blood.",
            'both': "You are a helpful blood donation assistant."
        }.get(user_role, "You are a helpful blood donation assistant.")

        system_prompt = f"""{role_persona}

Your task is to answer the user's question using the provided context from our blood donation knowledge base.

CONTEXT FROM KNOWLEDGE BASE:
{context}

INSTRUCTIONS:
1. Answer the user's question primarily using the provided context
2. If the context doesn't contain enough information, you can provide general guidance but recommend consulting a healthcare professional
3. Be clear, accurate, and friendly
4. For medical questions, always include a disclaimer that they should consult healthcare professionals
5. Keep responses concise (2-4 sentences when possible)
6. If the context directly answers the question, use that answer
7. Do not make up information - stick to what's in the context or general knowledge about blood donation"""

        try:
            if self.llm_provider == 'openai':
                response = self.client.chat.completions.create(
                    model=self.llm_model,
                    messages=[
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_question}
                    ],
                    temperature=self.temperature,
                    max_tokens=500
                )
                return response.choices[0].message.content.strip()

            elif self.llm_provider == 'anthropic':
                response = self.client.messages.create(
                    model=self.llm_model,
                    max_tokens=500,
                    temperature=self.temperature,
                    system=system_prompt,
                    messages=[
                        {"role": "user", "content": user_question}
                    ]
                )
                return response.content[0].text.strip()

            elif self.llm_provider == 'ollama':
                import requests
                response = requests.post(
                    f"{self.ollama_base_url}/api/generate",
                    json={
                        "model": self.llm_model,
                        "prompt": f"{system_prompt}\n\nUser: {user_question}\nAssistant:",
                        "stream": False,
                        "options": {
                            "temperature": self.temperature,
                            "num_predict": 500
                        }
                    },
                    timeout=30
                )
                return response.json().get('response', 'Error generating response').strip()

        except Exception as e:
            # Fallback to direct FAQ answer if LLM fails
            print(f"[ERROR] LLM generation failed: {e}")
            return None

    def get_answer(self, user_question: str, user_role: str = 'both', use_rag: bool = True) -> Dict:
        """
        Get answer using True RAG pipeline

        Args:
            user_question: The user's question
            user_role: User's role ('donor', 'patient', or 'both')
            use_rag: If True, use RAG with LLM; if False, use direct FAQ matching

        Returns:
            Dict with answer, confidence, metadata
        """
        # STEP 1: RETRIEVAL - Find relevant FAQs
        relevant_faqs = self._retrieve_relevant_faqs(user_question, user_role)

        if not relevant_faqs:
            return {
                'answer': "I couldn't find specific information about that in our knowledge base. "
                         "Please try rephrasing your question or contact our support team directly.",
                'confidence': 0.0,
                'category': None,
                'matched_question': None,
                'method': 'no_match'
            }

        # Get best match for metadata
        best_match = relevant_faqs[0]
        best_faq = best_match['faq']
        similarity_score = best_match['similarity']

        # If not using RAG, return direct FAQ answer
        if not use_rag:
            return {
                'answer': best_faq['answer'],
                'confidence': similarity_score,
                'category': best_faq.get('category'),
                'matched_question': best_faq['question'],
                'method': 'direct'
            }

        # STEP 2: BUILD CONTEXT
        context = self._build_context(relevant_faqs)

        # STEP 3: GENERATION - Use LLM to generate response
        generated_answer = self._generate_with_llm(user_question, context, user_role)

        # If LLM failed, fallback to direct FAQ answer
        if not generated_answer:
            return {
                'answer': best_faq['answer'],
                'confidence': similarity_score,
                'category': best_faq.get('category'),
                'matched_question': best_faq['question'],
                'method': 'fallback'
            }

        # Return RAG-generated answer
        return {
            'answer': generated_answer,
            'confidence': similarity_score,
            'category': best_faq.get('category'),
            'matched_question': best_faq['question'],
            'method': 'rag',
            'context_used': len(relevant_faqs),
            'top_faqs': [f['faq']['question'] for f in relevant_faqs[:3]]
        }

    def reload_faq(self):
        """Reload FAQ data from database"""
        self._load_from_db('both')
        self.load_role_specific_faqs()


# Global chatbot instance
_rag_chatbot_instance = None


def get_rag_chatbot():
    """Get or create the global RAG chatbot instance"""
    global _rag_chatbot_instance
    if _rag_chatbot_instance is None:
        _rag_chatbot_instance = TrueRAGChatbot()
    return _rag_chatbot_instance


def reload_rag_chatbot():
    """Reload the RAG chatbot with fresh data"""
    global _rag_chatbot_instance
    _rag_chatbot_instance = TrueRAGChatbot()
    return _rag_chatbot_instance
