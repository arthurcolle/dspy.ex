defmodule Dspy.Signature do
  @moduledoc """
  Define typed input/output interfaces for language model calls.

  Signatures specify the expected inputs and outputs for DSPy modules,
  including field types, descriptions, and validation rules.
  """

  defstruct [:name, :description, :input_fields, :output_fields, :instructions]

  defmacro __using__(_opts) do
    quote do
      import Dspy.Signature.DSL
      @before_compile Dspy.Signature.DSL
      
      Module.register_attribute(__MODULE__, :input_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :output_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :signature_description, accumulate: false)
      Module.register_attribute(__MODULE__, :signature_instructions, accumulate: false)
    end
  end

  @type field :: %{
          name: atom(),
          type: atom(),
          description: String.t(),
          required: boolean(),
          default: any()
        }

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t() | nil,
          input_fields: [field()],
          output_fields: [field()],
          instructions: String.t() | nil
        }

  @doc """
  Create a new signature.
  """
  def new(name, opts \\ []) do
    %__MODULE__{
      name: name,
      description: Keyword.get(opts, :description),
      input_fields: Keyword.get(opts, :input_fields, []),
      output_fields: Keyword.get(opts, :output_fields, []),
      instructions: Keyword.get(opts, :instructions)
    }
  end

  @doc """
  Define a signature from a string specification.
  
  Format: "function_name(input1: type, input2: type) -> output1: type, output2: type"
  """
  def define(signature_string) do
    case parse_signature_string(signature_string) do
      {:ok, {name, input_fields, output_fields}} ->
        new(name, input_fields: input_fields, output_fields: output_fields)
      
      {:error, reason} ->
        raise ArgumentError, "Invalid signature format: #{reason}"
    end
  end

  @doc """
  Get a predefined signature by name.
  """
  def get_predefined(name) when is_atom(name) do
    case name do
      # Basic signatures
      :question_answer -> question_answer()
      :classification -> classification()
      :reasoning -> reasoning()
      :code_generation -> code_generation()
      :summarization -> summarization()
      :translation -> translation()
      :mathematical_problem_solving -> mathematical_problem_solving()
      :proof_construction -> proof_construction()
      :pattern_recognition -> pattern_recognition()
      :creative_writing -> creative_writing()
      :data_analysis -> data_analysis()
      
      # Creative & Experimental
      :dream_interpretation -> dream_interpretation()
      :personality_analysis -> personality_analysis()
      :story_generation -> story_generation()
      :philosophical_reasoning -> philosophical_reasoning()
      :emotional_intelligence -> emotional_intelligence()
      :metaphor_creation -> metaphor_creation()
      :conspiracy_theory_debunking -> conspiracy_theory_debunking()
      :future_prediction -> future_prediction()
      :alternate_history -> alternate_history()
      :mystery_solving -> mystery_solving()
      :poetry_analysis -> poetry_analysis()
      :art_critique -> art_critique()
      :music_composition -> music_composition()
      :game_design -> game_design()
      :invention_brainstorming -> invention_brainstorming()
      
      # Domain-specific
      :medical_diagnosis -> medical_diagnosis()
      :legal_analysis -> legal_analysis()
      :scientific_hypothesis -> scientific_hypothesis()
      :financial_analysis -> financial_analysis()
      :psychological_assessment -> psychological_assessment()
      :architectural_design -> architectural_design()
      :culinary_creation -> culinary_creation()
      :fashion_design -> fashion_design()
      :environmental_impact -> environmental_impact()
      :space_exploration -> space_exploration()
      :quantum_physics -> quantum_physics()
      :biotechnology -> biotechnology()
      :cybersecurity -> cybersecurity()
      :urban_planning -> urban_planning()
      :education_design -> education_design()
      
      # Multi-modal & Advanced
      :image_analysis -> image_analysis()
      :video_understanding -> video_understanding()
      :audio_processing -> audio_processing()
      :multimodal_reasoning -> multimodal_reasoning()
      :code_review -> code_review()
      :system_design -> system_design()
      :project_management -> project_management()
      :negotiation_strategy -> negotiation_strategy()
      :cultural_translation -> cultural_translation()
      :behavioral_prediction -> behavioral_prediction()
      :trend_analysis -> trend_analysis()
      :risk_assessment -> risk_assessment()
      :ethical_evaluation -> ethical_evaluation()
      :cognitive_simulation -> cognitive_simulation()
      :social_dynamics -> social_dynamics()
      
      # Experimental & Futuristic
      :consciousness_modeling -> consciousness_modeling()
      :reality_synthesis -> reality_synthesis()
      :dimensional_analysis -> dimensional_analysis()
      :temporal_reasoning -> temporal_reasoning()
      :quantum_consciousness -> quantum_consciousness()
      :synthetic_biology -> synthetic_biology()
      :memetic_engineering -> memetic_engineering()
      :collective_intelligence -> collective_intelligence()
      :emergent_behavior -> emergent_behavior()
      :paradigm_shifting -> paradigm_shifting()
      
      _ -> raise ArgumentError, "Unknown predefined signature: #{name}"
    end
  end

  # Predefined signature types
  def question_answer do
    new("question_answer",
      input_fields: [
        %{name: :question, type: :string, description: "The question to answer", required: true, default: nil}
      ],
      output_fields: [
        %{name: :answer, type: :string, description: "The answer to the question", required: true, default: nil}
      ]
    )
  end

  def classification do
    new("classification",
      input_fields: [
        %{name: :text, type: :string, description: "The text to classify", required: true, default: nil}
      ],
      output_fields: [
        %{name: :category, type: :string, description: "The predicted category", required: true, default: nil},
        %{name: :confidence, type: :number, description: "Confidence score (0-1)", required: false, default: nil}
      ]
    )
  end

  def reasoning do
    new("reasoning",
      input_fields: [
        %{name: :problem, type: :string, description: "The problem to reason about", required: true, default: nil}
      ],
      output_fields: [
        %{name: :reasoning, type: :string, description: "Step-by-step reasoning", required: true, default: nil},
        %{name: :conclusion, type: :string, description: "Final conclusion", required: true, default: nil}
      ]
    )
  end

  def code_generation do
    new("code_generation",
      input_fields: [
        %{name: :requirements, type: :string, description: "Code requirements description", required: true, default: nil},
        %{name: :language, type: :string, description: "Programming language", required: false, default: "elixir"}
      ],
      output_fields: [
        %{name: :code, type: :code, description: "Generated code", required: true, default: nil},
        %{name: :explanation, type: :string, description: "Code explanation", required: false, default: nil}
      ]
    )
  end

  def summarization do
    new("summarization",
      input_fields: [
        %{name: :text, type: :string, description: "The text to summarize", required: true, default: nil},
        %{name: :length, type: :string, description: "Desired summary length (short/medium/long)", required: false, default: "medium"}
      ],
      output_fields: [
        %{name: :summary, type: :string, description: "Text summary", required: true, default: nil},
        %{name: :key_points, type: :string, description: "Key points extracted", required: false, default: nil}
      ]
    )
  end

  def translation do
    new("translation",
      input_fields: [
        %{name: :text, type: :string, description: "Text to translate", required: true, default: nil},
        %{name: :source_language, type: :string, description: "Source language", required: false, default: "auto"},
        %{name: :target_language, type: :string, description: "Target language", required: true, default: nil}
      ],
      output_fields: [
        %{name: :translation, type: :string, description: "Translated text", required: true, default: nil},
        %{name: :confidence, type: :number, description: "Translation confidence (0-1)", required: false, default: nil}
      ]
    )
  end

  def mathematical_problem_solving do
    new("mathematical_problem_solving",
      input_fields: [
        %{name: :problem, type: :string, description: "Mathematical problem statement", required: true, default: nil}
      ],
      output_fields: [
        %{name: :approach, type: :string, description: "Solution approach", required: true, default: nil},
        %{name: :solution_steps, type: :string, description: "Step-by-step solution", required: true, default: nil},
        %{name: :answer, type: :string, description: "Final answer", required: true, default: nil},
        %{name: :verification, type: :string, description: "Solution verification", required: false, default: nil}
      ]
    )
  end

  def proof_construction do
    new("proof_construction",
      input_fields: [
        %{name: :theorem, type: :string, description: "Theorem to prove", required: true, default: nil}
      ],
      output_fields: [
        %{name: :reasoning, type: :string, description: "Logical reasoning", required: true, default: nil},
        %{name: :proof_strategy, type: :string, description: "Proof strategy", required: true, default: nil},
        %{name: :proof, type: :string, description: "Complete formal proof", required: true, default: nil},
        %{name: :key_insight, type: :string, description: "Key insight", required: false, default: nil}
      ]
    )
  end

  def pattern_recognition do
    new("pattern_recognition",
      input_fields: [
        %{name: :sequence, type: :string, description: "Sequence or pattern to analyze", required: true, default: nil}
      ],
      output_fields: [
        %{name: :observations, type: :string, description: "Pattern observations", required: true, default: nil},
        %{name: :formula, type: :string, description: "Mathematical formula or rule", required: true, default: nil},
        %{name: :proof, type: :string, description: "Proof of formula", required: true, default: nil},
        %{name: :predictions, type: :string, description: "Next elements in sequence", required: true, default: nil}
      ]
    )
  end

  def creative_writing do
    new("creative_writing",
      input_fields: [
        %{name: :prompt, type: :string, description: "Writing prompt or topic", required: true, default: nil},
        %{name: :style, type: :string, description: "Writing style or genre", required: false, default: nil},
        %{name: :length, type: :string, description: "Desired length", required: false, default: "medium"}
      ],
      output_fields: [
        %{name: :content, type: :string, description: "Generated creative content", required: true, default: nil},
        %{name: :theme, type: :string, description: "Main theme or message", required: false, default: nil}
      ]
    )
  end

  def data_analysis do
    new("data_analysis",
      input_fields: [
        %{name: :data, type: :string, description: "Data to analyze", required: true, default: nil},
        %{name: :question, type: :string, description: "Analysis question", required: false, default: nil}
      ],
      output_fields: [
        %{name: :analysis, type: :string, description: "Data analysis results", required: true, default: nil},
        %{name: :insights, type: :string, description: "Key insights", required: true, default: nil},
        %{name: :visualization_suggestions, type: :string, description: "Suggested visualizations", required: false, default: nil}
      ]
    )
  end

  # === Creative & Experimental Signatures ===

  def dream_interpretation do
    new("dream_interpretation",
      input_fields: [
        %{name: :dream_description, type: :string, description: "Detailed description of the dream", required: true, default: nil},
        %{name: :dreamer_context, type: :string, description: "Life context and recent events", required: false, default: nil}
      ],
      output_fields: [
        %{name: :symbolic_analysis, type: :string, description: "Analysis of dream symbols", required: true, default: nil},
        %{name: :psychological_interpretation, type: :string, description: "Psychological meaning", required: true, default: nil},
        %{name: :emotional_themes, type: :string, description: "Underlying emotional themes", required: true, default: nil},
        %{name: :actionable_insights, type: :string, description: "Practical insights for waking life", required: false, default: nil}
      ]
    )
  end

  def personality_analysis do
    new("personality_analysis",
      input_fields: [
        %{name: :behavioral_data, type: :string, description: "Observable behaviors and traits", required: true, default: nil},
        %{name: :communication_style, type: :string, description: "How the person communicates", required: false, default: nil},
        %{name: :decision_patterns, type: :string, description: "Patterns in decision making", required: false, default: nil}
      ],
      output_fields: [
        %{name: :personality_type, type: :string, description: "Likely personality type", required: true, default: nil},
        %{name: :core_traits, type: :string, description: "Central personality traits", required: true, default: nil},
        %{name: :motivations, type: :string, description: "Primary motivations and drives", required: true, default: nil},
        %{name: :potential_blind_spots, type: :string, description: "Areas for growth", required: false, default: nil}
      ]
    )
  end

  def story_generation do
    new("story_generation",
      input_fields: [
        %{name: :genre, type: :string, description: "Story genre", required: true, default: nil},
        %{name: :characters, type: :string, description: "Main characters", required: false, default: nil},
        %{name: :setting, type: :string, description: "Time and place setting", required: false, default: nil},
        %{name: :theme, type: :string, description: "Central theme or message", required: false, default: nil},
        %{name: :length, type: :string, description: "Desired story length", required: false, default: "medium"}
      ],
      output_fields: [
        %{name: :story, type: :string, description: "Complete story narrative", required: true, default: nil},
        %{name: :character_arcs, type: :string, description: "Character development arcs", required: true, default: nil},
        %{name: :plot_structure, type: :string, description: "Plot structure analysis", required: false, default: nil},
        %{name: :literary_devices, type: :string, description: "Literary techniques used", required: false, default: nil}
      ]
    )
  end

  def philosophical_reasoning do
    new("philosophical_reasoning",
      input_fields: [
        %{name: :philosophical_question, type: :string, description: "Philosophical question or dilemma", required: true, default: nil},
        %{name: :context, type: :string, description: "Relevant context or background", required: false, default: nil}
      ],
      output_fields: [
        %{name: :multiple_perspectives, type: :string, description: "Different philosophical viewpoints", required: true, default: nil},
        %{name: :logical_analysis, type: :string, description: "Logical structure of arguments", required: true, default: nil},
        %{name: :ethical_implications, type: :string, description: "Ethical considerations", required: true, default: nil},
        %{name: :synthesis, type: :string, description: "Synthesized philosophical position", required: false, default: nil}
      ]
    )
  end

  def emotional_intelligence do
    new("emotional_intelligence",
      input_fields: [
        %{name: :situation, type: :string, description: "Social or emotional situation", required: true, default: nil},
        %{name: :people_involved, type: :string, description: "People and their apparent emotions", required: false, default: nil}
      ],
      output_fields: [
        %{name: :emotion_recognition, type: :string, description: "Identified emotions and triggers", required: true, default: nil},
        %{name: :empathy_analysis, type: :string, description: "Perspective-taking analysis", required: true, default: nil},
        %{name: :response_strategies, type: :string, description: "Emotionally intelligent responses", required: true, default: nil},
        %{name: :relationship_impact, type: :string, description: "Impact on relationships", required: false, default: nil}
      ]
    )
  end

  def metaphor_creation do
    new("metaphor_creation",
      input_fields: [
        %{name: :concept, type: :string, description: "Concept to create metaphors for", required: true, default: nil},
        %{name: :audience, type: :string, description: "Target audience", required: false, default: nil},
        %{name: :style, type: :string, description: "Metaphor style or approach", required: false, default: nil}
      ],
      output_fields: [
        %{name: :primary_metaphor, type: :string, description: "Main metaphor explanation", required: true, default: nil},
        %{name: :alternative_metaphors, type: :string, description: "Additional metaphor options", required: true, default: nil},
        %{name: :metaphor_analysis, type: :string, description: "Why these metaphors work", required: true, default: nil},
        %{name: :usage_examples, type: :string, description: "Examples of metaphor in use", required: false, default: nil}
      ]
    )
  end

  def conspiracy_theory_debunking do
    new("conspiracy_theory_debunking",
      input_fields: [
        %{name: :conspiracy_claim, type: :string, description: "Conspiracy theory claim", required: true, default: nil},
        %{name: :evidence_presented, type: :string, description: "Evidence cited by proponents", required: false, default: nil}
      ],
      output_fields: [
        %{name: :factual_analysis, type: :string, description: "Fact-checking and evidence evaluation", required: true, default: nil},
        %{name: :logical_fallacies, type: :string, description: "Logical fallacies identified", required: true, default: nil},
        %{name: :alternative_explanations, type: :string, description: "More plausible explanations", required: true, default: nil},
        %{name: :psychological_factors, type: :string, description: "Why people believe this theory", required: false, default: nil}
      ]
    )
  end

  def future_prediction do
    new("future_prediction",
      input_fields: [
        %{name: :current_trends, type: :string, description: "Current trends and data", required: true, default: nil},
        %{name: :time_horizon, type: :string, description: "Prediction timeframe", required: true, default: nil},
        %{name: :domain, type: :string, description: "Domain of prediction", required: false, default: nil}
      ],
      output_fields: [
        %{name: :predictions, type: :string, description: "Specific future predictions", required: true, default: nil},
        %{name: :probability_assessment, type: :string, description: "Likelihood of each prediction", required: true, default: nil},
        %{name: :key_factors, type: :string, description: "Critical factors affecting outcomes", required: true, default: nil},
        %{name: :uncertainty_analysis, type: :string, description: "Sources of uncertainty", required: false, default: nil}
      ]
    )
  end

  def alternate_history do
    new("alternate_history",
      input_fields: [
        %{name: :historical_event, type: :string, description: "Historical event to alter", required: true, default: nil},
        %{name: :change_description, type: :string, description: "How the event changes", required: true, default: nil},
        %{name: :scope, type: :string, description: "Geographic or temporal scope", required: false, default: nil}
      ],
      output_fields: [
        %{name: :immediate_consequences, type: :string, description: "Direct immediate effects", required: true, default: nil},
        %{name: :long_term_implications, type: :string, description: "Long-term historical changes", required: true, default: nil},
        %{name: :butterfly_effects, type: :string, description: "Unexpected cascading effects", required: true, default: nil},
        %{name: :plausibility_analysis, type: :string, description: "Historical plausibility assessment", required: false, default: nil}
      ]
    )
  end

  def mystery_solving do
    new("mystery_solving",
      input_fields: [
        %{name: :mystery_description, type: :string, description: "Description of the mystery", required: true, default: nil},
        %{name: :available_clues, type: :string, description: "Known clues and evidence", required: false, default: nil},
        %{name: :constraints, type: :string, description: "Known constraints or rules", required: false, default: nil}
      ],
      output_fields: [
        %{name: :deductive_analysis, type: :string, description: "Logical deduction process", required: true, default: nil},
        %{name: :possible_solutions, type: :string, description: "Potential solutions ranked", required: true, default: nil},
        %{name: :evidence_gaps, type: :string, description: "Missing information needed", required: true, default: nil},
        %{name: :investigation_strategy, type: :string, description: "Next steps for solving", required: false, default: nil}
      ]
    )
  end

  def poetry_analysis do
    new("poetry_analysis",
      input_fields: [
        %{name: :poem_text, type: :string, description: "The poem to analyze", required: true, default: nil},
        %{name: :poet_background, type: :string, description: "Information about the poet", required: false, default: nil},
        %{name: :historical_context, type: :string, description: "Historical context", required: false, default: nil}
      ],
      output_fields: [
        %{name: :literary_devices, type: :string, description: "Poetic techniques and devices", required: true, default: nil},
        %{name: :themes_and_meaning, type: :string, description: "Central themes and meaning", required: true, default: nil},
        %{name: :emotional_impact, type: :string, description: "Emotional resonance and effect", required: true, default: nil},
        %{name: :cultural_significance, type: :string, description: "Cultural and historical significance", required: false, default: nil}
      ]
    )
  end

  def art_critique do
    new("art_critique",
      input_fields: [
        %{name: :artwork_description, type: :string, description: "Description of the artwork", required: true, default: nil},
        %{name: :artist_information, type: :string, description: "Information about the artist", required: false, default: nil},
        %{name: :medium_and_technique, type: :string, description: "Artistic medium and techniques", required: false, default: nil}
      ],
      output_fields: [
        %{name: :formal_analysis, type: :string, description: "Composition, color, form analysis", required: true, default: nil},
        %{name: :conceptual_interpretation, type: :string, description: "Meaning and conceptual content", required: true, default: nil},
        %{name: :artistic_context, type: :string, description: "Art historical context", required: true, default: nil},
        %{name: :aesthetic_evaluation, type: :string, description: "Aesthetic merit and impact", required: false, default: nil}
      ]
    )
  end

  def music_composition do
    new("music_composition",
      input_fields: [
        %{name: :style_or_genre, type: :string, description: "Musical style or genre", required: true, default: nil},
        %{name: :mood_or_emotion, type: :string, description: "Desired mood or emotion", required: false, default: nil},
        %{name: :instrumentation, type: :string, description: "Instruments to include", required: false, default: nil},
        %{name: :duration, type: :string, description: "Approximate duration", required: false, default: nil}
      ],
      output_fields: [
        %{name: :composition_structure, type: :string, description: "Overall musical structure", required: true, default: nil},
        %{name: :melodic_themes, type: :string, description: "Main melodic themes", required: true, default: nil},
        %{name: :harmonic_progression, type: :string, description: "Chord progressions and harmony", required: true, default: nil},
        %{name: :performance_notes, type: :string, description: "Performance guidelines", required: false, default: nil}
      ]
    )
  end

  def game_design do
    new("game_design",
      input_fields: [
        %{name: :game_concept, type: :string, description: "Basic game concept or idea", required: true, default: nil},
        %{name: :target_audience, type: :string, description: "Intended player demographic", required: false, default: nil},
        %{name: :platform, type: :string, description: "Gaming platform(s)", required: false, default: nil},
        %{name: :genre_preferences, type: :string, description: "Preferred game genres", required: false, default: nil}
      ],
      output_fields: [
        %{name: :core_mechanics, type: :string, description: "Core gameplay mechanics", required: true, default: nil},
        %{name: :progression_system, type: :string, description: "Player progression and rewards", required: true, default: nil},
        %{name: :narrative_elements, type: :string, description: "Story and narrative design", required: true, default: nil},
        %{name: :monetization_strategy, type: :string, description: "Business model considerations", required: false, default: nil}
      ]
    )
  end

  def invention_brainstorming do
    new("invention_brainstorming",
      input_fields: [
        %{name: :problem_statement, type: :string, description: "Problem to solve", required: true, default: nil},
        %{name: :constraints, type: :string, description: "Technical or resource constraints", required: false, default: nil},
        %{name: :target_users, type: :string, description: "Who would use this invention", required: false, default: nil}
      ],
      output_fields: [
        %{name: :invention_concepts, type: :string, description: "Multiple invention ideas", required: true, default: nil},
        %{name: :technical_feasibility, type: :string, description: "Technical feasibility analysis", required: true, default: nil},
        %{name: :innovation_potential, type: :string, description: "Novelty and innovation assessment", required: true, default: nil},
        %{name: :implementation_roadmap, type: :string, description: "Development pathway", required: false, default: nil}
      ]
    )
  end

  # === Domain-specific Signatures ===

  def medical_diagnosis do
    new("medical_diagnosis",
      input_fields: [
        %{name: :symptoms, type: :string, description: "Patient symptoms and presentation", required: true, default: nil},
        %{name: :medical_history, type: :string, description: "Relevant medical history", required: false, default: nil},
        %{name: :test_results, type: :string, description: "Laboratory or imaging results", required: false, default: nil},
        %{name: :patient_demographics, type: :string, description: "Age, sex, and relevant demographics", required: false, default: nil}
      ],
      output_fields: [
        %{name: :differential_diagnosis, type: :string, description: "Ranked list of possible diagnoses", required: true, default: nil},
        %{name: :recommended_tests, type: :string, description: "Additional tests needed", required: true, default: nil},
        %{name: :treatment_options, type: :string, description: "Possible treatment approaches", required: true, default: nil},
        %{name: :prognosis, type: :string, description: "Expected outcomes and timeline", required: false, default: nil}
      ]
    )
  end

  def legal_analysis do
    new("legal_analysis",
      input_fields: [
        %{name: :case_facts, type: :string, description: "Factual circumstances of the case", required: true, default: nil},
        %{name: :jurisdiction, type: :string, description: "Legal jurisdiction and applicable law", required: true, default: nil},
        %{name: :legal_questions, type: :string, description: "Specific legal questions at issue", required: false, default: nil},
        %{name: :precedent_cases, type: :string, description: "Relevant case law", required: false, default: nil}
      ],
      output_fields: [
        %{name: :legal_issues, type: :string, description: "Identified legal issues", required: true, default: nil},
        %{name: :applicable_law, type: :string, description: "Relevant statutes and case law", required: true, default: nil},
        %{name: :legal_arguments, type: :string, description: "Potential legal arguments", required: true, default: nil},
        %{name: :outcome_prediction, type: :string, description: "Likely legal outcomes", required: false, default: nil}
      ]
    )
  end

  def scientific_hypothesis do
    new("scientific_hypothesis",
      input_fields: [
        %{name: :research_question, type: :string, description: "Scientific question to investigate", required: true, default: nil},
        %{name: :background_knowledge, type: :string, description: "Existing scientific knowledge", required: false, default: nil},
        %{name: :observations, type: :string, description: "Preliminary observations or data", required: false, default: nil},
        %{name: :field_of_study, type: :string, description: "Scientific discipline", required: false, default: nil}
      ],
      output_fields: [
        %{name: :hypothesis, type: :string, description: "Testable scientific hypothesis", required: true, default: nil},
        %{name: :experimental_design, type: :string, description: "Proposed experimental approach", required: true, default: nil},
        %{name: :variables_and_controls, type: :string, description: "Independent, dependent, and control variables", required: true, default: nil},
        %{name: :predictions, type: :string, description: "Expected experimental outcomes", required: false, default: nil}
      ]
    )
  end

  def financial_analysis do
    new("financial_analysis",
      input_fields: [
        %{name: :financial_data, type: :string, description: "Financial statements and data", required: true, default: nil},
        %{name: :company_industry, type: :string, description: "Industry and business context", required: false, default: nil},
        %{name: :analysis_purpose, type: :string, description: "Purpose of analysis (investment, valuation, etc.)", required: false, default: nil},
        %{name: :time_period, type: :string, description: "Time period for analysis", required: false, default: nil}
      ],
      output_fields: [
        %{name: :financial_health, type: :string, description: "Overall financial health assessment", required: true, default: nil},
        %{name: :key_ratios, type: :string, description: "Important financial ratios and metrics", required: true, default: nil},
        %{name: :trends_analysis, type: :string, description: "Financial trends and patterns", required: true, default: nil},
        %{name: :investment_recommendation, type: :string, description: "Investment or business recommendation", required: false, default: nil}
      ]
    )
  end

  def psychological_assessment do
    new("psychological_assessment",
      input_fields: [
        %{name: :behavioral_observations, type: :string, description: "Observed behaviors and patterns", required: true, default: nil},
        %{name: :assessment_context, type: :string, description: "Context and purpose of assessment", required: false, default: nil},
        %{name: :background_information, type: :string, description: "Relevant personal history", required: false, default: nil},
        %{name: :assessment_tools, type: :string, description: "Tests or instruments used", required: false, default: nil}
      ],
      output_fields: [
        %{name: :psychological_profile, type: :string, description: "Comprehensive psychological profile", required: true, default: nil},
        %{name: :areas_of_concern, type: :string, description: "Identified areas needing attention", required: true, default: nil},
        %{name: :strengths_and_resources, type: :string, description: "Personal strengths and coping resources", required: true, default: nil},
        %{name: :recommendations, type: :string, description: "Treatment or intervention recommendations", required: false, default: nil}
      ]
    )
  end

  def architectural_design do
    new("architectural_design",
      input_fields: [
        %{name: :project_requirements, type: :string, description: "Functional and spatial requirements", required: true, default: nil},
        %{name: :site_conditions, type: :string, description: "Site characteristics and constraints", required: false, default: nil},
        %{name: :budget_constraints, type: :string, description: "Budget and cost considerations", required: false, default: nil},
        %{name: :design_style, type: :string, description: "Preferred architectural style", required: false, default: nil}
      ],
      output_fields: [
        %{name: :design_concept, type: :string, description: "Overall design concept and approach", required: true, default: nil},
        %{name: :spatial_organization, type: :string, description: "Layout and spatial relationships", required: true, default: nil},
        %{name: :structural_considerations, type: :string, description: "Structural system and materials", required: true, default: nil},
        %{name: :sustainability_features, type: :string, description: "Environmental and sustainability aspects", required: false, default: nil}
      ]
    )
  end

  def culinary_creation do
    new("culinary_creation",
      input_fields: [
        %{name: :cuisine_type, type: :string, description: "Cuisine style or cultural influence", required: true, default: nil},
        %{name: :dietary_restrictions, type: :string, description: "Dietary limitations or preferences", required: false, default: nil},
        %{name: :available_ingredients, type: :string, description: "Available or preferred ingredients", required: false, default: nil},
        %{name: :meal_context, type: :string, description: "Occasion or meal type", required: false, default: nil}
      ],
      output_fields: [
        %{name: :recipe_creation, type: :string, description: "Complete recipe with instructions", required: true, default: nil},
        %{name: :flavor_profile, type: :string, description: "Taste and flavor characteristics", required: true, default: nil},
        %{name: :presentation_ideas, type: :string, description: "Plating and presentation suggestions", required: true, default: nil},
        %{name: :pairing_suggestions, type: :string, description: "Complementary dishes or beverages", required: false, default: nil}
      ]
    )
  end

  def fashion_design do
    new("fashion_design",
      input_fields: [
        %{name: :design_brief, type: :string, description: "Design concept or inspiration", required: true, default: nil},
        %{name: :target_market, type: :string, description: "Target demographic and market", required: false, default: nil},
        %{name: :season_occasion, type: :string, description: "Season or occasion for wearing", required: false, default: nil},
        %{name: :budget_tier, type: :string, description: "Price point and market tier", required: false, default: nil}
      ],
      output_fields: [
        %{name: :design_concept, type: :string, description: "Overall design concept and aesthetic", required: true, default: nil},
        %{name: :garment_details, type: :string, description: "Specific garment specifications", required: true, default: nil},
        %{name: :materials_and_fabrics, type: :string, description: "Fabric choices and material specifications", required: true, default: nil},
        %{name: :trend_alignment, type: :string, description: "Alignment with current fashion trends", required: false, default: nil}
      ]
    )
  end

  def environmental_impact do
    new("environmental_impact",
      input_fields: [
        %{name: :project_description, type: :string, description: "Project or activity description", required: true, default: nil},
        %{name: :environmental_context, type: :string, description: "Environmental setting and conditions", required: false, default: nil},
        %{name: :scope_and_scale, type: :string, description: "Scale and scope of impact", required: false, default: nil},
        %{name: :regulatory_framework, type: :string, description: "Applicable environmental regulations", required: false, default: nil}
      ],
      output_fields: [
        %{name: :impact_assessment, type: :string, description: "Comprehensive environmental impact analysis", required: true, default: nil},
        %{name: :mitigation_measures, type: :string, description: "Proposed environmental mitigation strategies", required: true, default: nil},
        %{name: :monitoring_plan, type: :string, description: "Environmental monitoring recommendations", required: true, default: nil},
        %{name: :compliance_requirements, type: :string, description: "Regulatory compliance needs", required: false, default: nil}
      ]
    )
  end

  def space_exploration do
    new("space_exploration",
      input_fields: [
        %{name: :mission_objectives, type: :string, description: "Primary mission goals and objectives", required: true, default: nil},
        %{name: :target_destination, type: :string, description: "Destination (planet, moon, asteroid, etc.)", required: false, default: nil},
        %{name: :mission_duration, type: :string, description: "Expected mission timeline", required: false, default: nil},
        %{name: :technological_constraints, type: :string, description: "Current technological limitations", required: false, default: nil}
      ],
      output_fields: [
        %{name: :mission_design, type: :string, description: "Complete mission architecture", required: true, default: nil},
        %{name: :technological_requirements, type: :string, description: "Required technologies and systems", required: true, default: nil},
        %{name: :risk_assessment, type: :string, description: "Mission risks and mitigation strategies", required: true, default: nil},
        %{name: :scientific_potential, type: :string, description: "Expected scientific discoveries", required: false, default: nil}
      ]
    )
  end

  def quantum_physics do
    new("quantum_physics",
      input_fields: [
        %{name: :quantum_system, type: :string, description: "Quantum system under study", required: true, default: nil},
        %{name: :physical_parameters, type: :string, description: "Relevant physical parameters", required: false, default: nil},
        %{name: :experimental_setup, type: :string, description: "Experimental or theoretical setup", required: false, default: nil},
        %{name: :research_question, type: :string, description: "Specific quantum phenomenon to investigate", required: false, default: nil}
      ],
      output_fields: [
        %{name: :quantum_analysis, type: :string, description: "Quantum mechanical analysis", required: true, default: nil},
        %{name: :mathematical_framework, type: :string, description: "Mathematical formulation and equations", required: true, default: nil},
        %{name: :physical_interpretation, type: :string, description: "Physical meaning and implications", required: true, default: nil},
        %{name: :experimental_predictions, type: :string, description: "Testable experimental predictions", required: false, default: nil}
      ]
    )
  end

  def biotechnology do
    new("biotechnology",
      input_fields: [
        %{name: :biological_target, type: :string, description: "Biological system or target", required: true, default: nil},
        %{name: :application_goal, type: :string, description: "Intended application or outcome", required: true, default: nil},
        %{name: :available_tools, type: :string, description: "Available biotechnological tools", required: false, default: nil},
        %{name: :regulatory_considerations, type: :string, description: "Regulatory and ethical constraints", required: false, default: nil}
      ],
      output_fields: [
        %{name: :biotechnological_approach, type: :string, description: "Proposed biotechnological strategy", required: true, default: nil},
        %{name: :technical_methodology, type: :string, description: "Detailed technical methodology", required: true, default: nil},
        %{name: :risk_benefit_analysis, type: :string, description: "Risk and benefit assessment", required: true, default: nil},
        %{name: :commercialization_potential, type: :string, description: "Commercial viability and applications", required: false, default: nil}
      ]
    )
  end

  def cybersecurity do
    new("cybersecurity",
      input_fields: [
        %{name: :system_description, type: :string, description: "System or network to secure", required: true, default: nil},
        %{name: :threat_landscape, type: :string, description: "Known or potential threats", required: false, default: nil},
        %{name: :security_requirements, type: :string, description: "Security requirements and compliance needs", required: false, default: nil},
        %{name: :current_measures, type: :string, description: "Existing security measures", required: false, default: nil}
      ],
      output_fields: [
        %{name: :vulnerability_assessment, type: :string, description: "Identified vulnerabilities and risks", required: true, default: nil},
        %{name: :security_recommendations, type: :string, description: "Recommended security measures", required: true, default: nil},
        %{name: :implementation_plan, type: :string, description: "Security implementation roadmap", required: true, default: nil},
        %{name: :monitoring_strategy, type: :string, description: "Ongoing security monitoring approach", required: false, default: nil}
      ]
    )
  end

  def urban_planning do
    new("urban_planning",
      input_fields: [
        %{name: :area_description, type: :string, description: "Urban area characteristics", required: true, default: nil},
        %{name: :planning_objectives, type: :string, description: "Planning goals and objectives", required: true, default: nil},
        %{name: :demographic_data, type: :string, description: "Population and demographic information", required: false, default: nil},
        %{name: :existing_infrastructure, type: :string, description: "Current infrastructure and land use", required: false, default: nil}
      ],
      output_fields: [
        %{name: :development_plan, type: :string, description: "Comprehensive development strategy", required: true, default: nil},
        %{name: :zoning_recommendations, type: :string, description: "Land use and zoning proposals", required: true, default: nil},
        %{name: :infrastructure_needs, type: :string, description: "Infrastructure development requirements", required: true, default: nil},
        %{name: :sustainability_measures, type: :string, description: "Environmental and sustainability considerations", required: false, default: nil}
      ]
    )
  end

  def education_design do
    new("education_design",
      input_fields: [
        %{name: :learning_objectives, type: :string, description: "Educational goals and learning outcomes", required: true, default: nil},
        %{name: :target_learners, type: :string, description: "Target student demographics and characteristics", required: true, default: nil},
        %{name: :subject_matter, type: :string, description: "Content area or subject matter", required: false, default: nil},
        %{name: :constraints, type: :string, description: "Time, resource, or technological constraints", required: false, default: nil}
      ],
      output_fields: [
        %{name: :curriculum_design, type: :string, description: "Comprehensive curriculum structure", required: true, default: nil},
        %{name: :teaching_strategies, type: :string, description: "Recommended pedagogical approaches", required: true, default: nil},
        %{name: :assessment_methods, type: :string, description: "Learning assessment and evaluation methods", required: true, default: nil},
        %{name: :technology_integration, type: :string, description: "Educational technology recommendations", required: false, default: nil}
      ]
    )
  end

  # === Multi-modal & Advanced Signatures ===

  def image_analysis do
    new("image_analysis",
      input_fields: [
        %{name: :image_description, type: :string, description: "Description of the image", required: true, default: nil},
        %{name: :analysis_purpose, type: :string, description: "Purpose of analysis", required: false, default: nil},
        %{name: :context, type: :string, description: "Additional context", required: false, default: nil}
      ],
      output_fields: [
        %{name: :visual_elements, type: :string, description: "Description of visual elements", required: true, default: nil},
        %{name: :composition_analysis, type: :string, description: "Composition and layout analysis", required: true, default: nil},
        %{name: :interpretation, type: :string, description: "Interpretation and meaning", required: true, default: nil},
        %{name: :technical_details, type: :string, description: "Technical photographic details", required: false, default: nil}
      ]
    )
  end

  def video_understanding do
    new("video_understanding",
      input_fields: [
        %{name: :video_description, type: :string, description: "Description of video content", required: true, default: nil},
        %{name: :duration, type: :string, description: "Video duration", required: false, default: nil},
        %{name: :analysis_goals, type: :string, description: "What to analyze in the video", required: false, default: nil}
      ],
      output_fields: [
        %{name: :content_summary, type: :string, description: "Summary of video content", required: true, default: nil},
        %{name: :narrative_structure, type: :string, description: "Story structure and flow", required: true, default: nil},
        %{name: :technical_analysis, type: :string, description: "Cinematography and production analysis", required: true, default: nil},
        %{name: :audience_impact, type: :string, description: "Likely audience reception", required: false, default: nil}
      ]
    )
  end

  def audio_processing do
    new("audio_processing",
      input_fields: [
        %{name: :audio_description, type: :string, description: "Description of audio content", required: true, default: nil},
        %{name: :audio_type, type: :string, description: "Type of audio (music, speech, etc.)", required: false, default: nil},
        %{name: :processing_goal, type: :string, description: "Goal of audio processing", required: false, default: nil}
      ],
      output_fields: [
        %{name: :audio_analysis, type: :string, description: "Analysis of audio characteristics", required: true, default: nil},
        %{name: :content_extraction, type: :string, description: "Extracted content or meaning", required: true, default: nil},
        %{name: :quality_assessment, type: :string, description: "Audio quality evaluation", required: true, default: nil},
        %{name: :enhancement_suggestions, type: :string, description: "Audio improvement recommendations", required: false, default: nil}
      ]
    )
  end

  def multimodal_reasoning do
    new("multimodal_reasoning",
      input_fields: [
        %{name: :visual_input, type: :string, description: "Visual information", required: false, default: nil},
        %{name: :textual_input, type: :string, description: "Textual information", required: false, default: nil},
        %{name: :audio_input, type: :string, description: "Audio information", required: false, default: nil},
        %{name: :reasoning_task, type: :string, description: "Specific reasoning task", required: true, default: nil}
      ],
      output_fields: [
        %{name: :integrated_analysis, type: :string, description: "Analysis across all modalities", required: true, default: nil},
        %{name: :cross_modal_insights, type: :string, description: "Insights from combining modalities", required: true, default: nil},
        %{name: :reasoning_process, type: :string, description: "Step-by-step reasoning", required: true, default: nil},
        %{name: :confidence_assessment, type: :string, description: "Confidence in reasoning", required: false, default: nil}
      ]
    )
  end

  def code_review do
    new("code_review",
      input_fields: [
        %{name: :code_snippet, type: :code, description: "Code to review", required: true, default: nil},
        %{name: :programming_language, type: :string, description: "Programming language", required: false, default: nil},
        %{name: :review_focus, type: :string, description: "Specific aspects to focus on", required: false, default: nil},
        %{name: :project_context, type: :string, description: "Project context and requirements", required: false, default: nil}
      ],
      output_fields: [
        %{name: :code_quality_assessment, type: :string, description: "Overall code quality evaluation", required: true, default: nil},
        %{name: :issues_and_bugs, type: :string, description: "Identified issues and potential bugs", required: true, default: nil},
        %{name: :improvement_suggestions, type: :string, description: "Specific improvement recommendations", required: true, default: nil},
        %{name: :best_practices, type: :string, description: "Best practice recommendations", required: false, default: nil}
      ]
    )
  end

  def system_design do
    new("system_design",
      input_fields: [
        %{name: :requirements, type: :string, description: "System requirements and constraints", required: true, default: nil},
        %{name: :scale_expectations, type: :string, description: "Expected scale and performance", required: false, default: nil},
        %{name: :technology_preferences, type: :string, description: "Preferred technologies or limitations", required: false, default: nil},
        %{name: :budget_constraints, type: :string, description: "Budget and resource constraints", required: false, default: nil}
      ],
      output_fields: [
        %{name: :architecture_design, type: :string, description: "High-level system architecture", required: true, default: nil},
        %{name: :component_specifications, type: :string, description: "Detailed component specifications", required: true, default: nil},
        %{name: :scalability_plan, type: :string, description: "Scalability and performance strategy", required: true, default: nil},
        %{name: :implementation_roadmap, type: :string, description: "Implementation phases and timeline", required: false, default: nil}
      ]
    )
  end

  def project_management do
    new("project_management",
      input_fields: [
        %{name: :project_description, type: :string, description: "Project goals and deliverables", required: true, default: nil},
        %{name: :timeline, type: :string, description: "Project timeline and deadlines", required: false, default: nil},
        %{name: :resources, type: :string, description: "Available resources and team", required: false, default: nil},
        %{name: :constraints, type: :string, description: "Project constraints and limitations", required: false, default: nil}
      ],
      output_fields: [
        %{name: :project_plan, type: :string, description: "Comprehensive project plan", required: true, default: nil},
        %{name: :task_breakdown, type: :string, description: "Work breakdown structure", required: true, default: nil},
        %{name: :risk_management, type: :string, description: "Risk identification and mitigation", required: true, default: nil},
        %{name: :success_metrics, type: :string, description: "Key performance indicators", required: false, default: nil}
      ]
    )
  end

  def negotiation_strategy do
    new("negotiation_strategy",
      input_fields: [
        %{name: :negotiation_context, type: :string, description: "Context and subject of negotiation", required: true, default: nil},
        %{name: :parties_involved, type: :string, description: "Parties and their interests", required: false, default: nil},
        %{name: :desired_outcomes, type: :string, description: "Preferred negotiation outcomes", required: false, default: nil},
        %{name: :constraints, type: :string, description: "Constraints and non-negotiables", required: false, default: nil}
      ],
      output_fields: [
        %{name: :negotiation_approach, type: :string, description: "Overall negotiation strategy", required: true, default: nil},
        %{name: :tactics_and_techniques, type: :string, description: "Specific negotiation tactics", required: true, default: nil},
        %{name: :preparation_checklist, type: :string, description: "Pre-negotiation preparation", required: true, default: nil},
        %{name: :fallback_options, type: :string, description: "Alternative outcomes and BATNA", required: false, default: nil}
      ]
    )
  end

  def cultural_translation do
    new("cultural_translation",
      input_fields: [
        %{name: :source_culture, type: :string, description: "Source cultural context", required: true, default: nil},
        %{name: :target_culture, type: :string, description: "Target cultural context", required: true, default: nil},
        %{name: :content_to_translate, type: :string, description: "Content requiring cultural adaptation", required: true, default: nil},
        %{name: :communication_purpose, type: :string, description: "Purpose of communication", required: false, default: nil}
      ],
      output_fields: [
        %{name: :cultural_adaptation, type: :string, description: "Culturally adapted content", required: true, default: nil},
        %{name: :cultural_considerations, type: :string, description: "Key cultural differences to consider", required: true, default: nil},
        %{name: :potential_misunderstandings, type: :string, description: "Potential cultural misunderstandings", required: true, default: nil},
        %{name: :communication_tips, type: :string, description: "Cross-cultural communication advice", required: false, default: nil}
      ]
    )
  end

  def behavioral_prediction do
    new("behavioral_prediction",
      input_fields: [
        %{name: :behavioral_data, type: :string, description: "Historical behavioral patterns", required: true, default: nil},
        %{name: :contextual_factors, type: :string, description: "Relevant contextual influences", required: false, default: nil},
        %{name: :prediction_timeframe, type: :string, description: "Timeframe for predictions", required: false, default: nil},
        %{name: :specific_behaviors, type: :string, description: "Specific behaviors to predict", required: false, default: nil}
      ],
      output_fields: [
        %{name: :behavior_predictions, type: :string, description: "Predicted behavioral outcomes", required: true, default: nil},
        %{name: :confidence_levels, type: :string, description: "Confidence in predictions", required: true, default: nil},
        %{name: :influencing_factors, type: :string, description: "Key factors affecting behavior", required: true, default: nil},
        %{name: :intervention_opportunities, type: :string, description: "Opportunities to influence behavior", required: false, default: nil}
      ]
    )
  end

  def trend_analysis do
    new("trend_analysis",
      input_fields: [
        %{name: :trend_data, type: :string, description: "Historical trend data", required: true, default: nil},
        %{name: :analysis_domain, type: :string, description: "Domain or field of analysis", required: false, default: nil},
        %{name: :time_horizon, type: :string, description: "Time period for analysis", required: false, default: nil},
        %{name: :external_factors, type: :string, description: "External factors to consider", required: false, default: nil}
      ],
      output_fields: [
        %{name: :trend_identification, type: :string, description: "Identified trends and patterns", required: true, default: nil},
        %{name: :trend_drivers, type: :string, description: "Underlying drivers of trends", required: true, default: nil},
        %{name: :future_projections, type: :string, description: "Future trend projections", required: true, default: nil},
        %{name: :strategic_implications, type: :string, description: "Strategic implications and opportunities", required: false, default: nil}
      ]
    )
  end

  def risk_assessment do
    new("risk_assessment",
      input_fields: [
        %{name: :scenario_description, type: :string, description: "Scenario or situation to assess", required: true, default: nil},
        %{name: :risk_categories, type: :string, description: "Types of risks to consider", required: false, default: nil},
        %{name: :stakeholders, type: :string, description: "Affected stakeholders", required: false, default: nil},
        %{name: :assessment_timeframe, type: :string, description: "Timeframe for risk assessment", required: false, default: nil}
      ],
      output_fields: [
        %{name: :risk_identification, type: :string, description: "Identified risks and vulnerabilities", required: true, default: nil},
        %{name: :probability_impact, type: :string, description: "Risk probability and impact analysis", required: true, default: nil},
        %{name: :mitigation_strategies, type: :string, description: "Risk mitigation recommendations", required: true, default: nil},
        %{name: :monitoring_plan, type: :string, description: "Ongoing risk monitoring approach", required: false, default: nil}
      ]
    )
  end

  def ethical_evaluation do
    new("ethical_evaluation",
      input_fields: [
        %{name: :situation_description, type: :string, description: "Situation requiring ethical evaluation", required: true, default: nil},
        %{name: :stakeholders, type: :string, description: "Affected parties and stakeholders", required: false, default: nil},
        %{name: :ethical_frameworks, type: :string, description: "Relevant ethical frameworks", required: false, default: nil},
        %{name: :cultural_context, type: :string, description: "Cultural and social context", required: false, default: nil}
      ],
      output_fields: [
        %{name: :ethical_analysis, type: :string, description: "Comprehensive ethical analysis", required: true, default: nil},
        %{name: :moral_considerations, type: :string, description: "Key moral considerations", required: true, default: nil},
        %{name: :ethical_recommendations, type: :string, description: "Ethically sound recommendations", required: true, default: nil},
        %{name: :stakeholder_impact, type: :string, description: "Impact on different stakeholders", required: false, default: nil}
      ]
    )
  end

  def cognitive_simulation do
    new("cognitive_simulation",
      input_fields: [
        %{name: :cognitive_task, type: :string, description: "Cognitive task or process to simulate", required: true, default: nil},
        %{name: :subject_characteristics, type: :string, description: "Characteristics of the thinking subject", required: false, default: nil},
        %{name: :environmental_factors, type: :string, description: "Environmental influences on cognition", required: false, default: nil},
        %{name: :simulation_goals, type: :string, description: "Goals of the cognitive simulation", required: false, default: nil}
      ],
      output_fields: [
        %{name: :cognitive_process, type: :string, description: "Simulated cognitive process", required: true, default: nil},
        %{name: :decision_points, type: :string, description: "Key decision points and choices", required: true, default: nil},
        %{name: :cognitive_biases, type: :string, description: "Potential cognitive biases", required: true, default: nil},
        %{name: :alternative_processes, type: :string, description: "Alternative cognitive approaches", required: false, default: nil}
      ]
    )
  end

  def social_dynamics do
    new("social_dynamics",
      input_fields: [
        %{name: :social_context, type: :string, description: "Social situation or group context", required: true, default: nil},
        %{name: :group_composition, type: :string, description: "Group members and their roles", required: false, default: nil},
        %{name: :interaction_goals, type: :string, description: "Goals of social interaction", required: false, default: nil},
        %{name: :cultural_factors, type: :string, description: "Cultural and social norms", required: false, default: nil}
      ],
      output_fields: [
        %{name: :dynamics_analysis, type: :string, description: "Analysis of social dynamics", required: true, default: nil},
        %{name: :power_structures, type: :string, description: "Power relationships and hierarchies", required: true, default: nil},
        %{name: :influence_patterns, type: :string, description: "Patterns of social influence", required: true, default: nil},
        %{name: :intervention_strategies, type: :string, description: "Strategies for positive intervention", required: false, default: nil}
      ]
    )
  end

  # === Experimental & Futuristic Signatures ===

  def consciousness_modeling do
    new("consciousness_modeling",
      input_fields: [
        %{name: :conscious_entity, type: :string, description: "Entity whose consciousness to model", required: true, default: nil},
        %{name: :consciousness_aspects, type: :string, description: "Aspects of consciousness to explore", required: false, default: nil},
        %{name: :theoretical_framework, type: :string, description: "Consciousness theory framework", required: false, default: nil}
      ],
      output_fields: [
        %{name: :consciousness_model, type: :string, description: "Model of consciousness structure", required: true, default: nil},
        %{name: :awareness_levels, type: :string, description: "Different levels of awareness", required: true, default: nil},
        %{name: :subjective_experience, type: :string, description: "Modeled subjective experience", required: true, default: nil},
        %{name: :emergence_properties, type: :string, description: "Emergent properties of consciousness", required: false, default: nil}
      ]
    )
  end

  def reality_synthesis do
    new("reality_synthesis",
      input_fields: [
        %{name: :reality_fragments, type: :string, description: "Fragments of reality to synthesize", required: true, default: nil},
        %{name: :synthesis_goal, type: :string, description: "Goal of reality synthesis", required: false, default: nil},
        %{name: :coherence_constraints, type: :string, description: "Constraints for reality coherence", required: false, default: nil}
      ],
      output_fields: [
        %{name: :synthesized_reality, type: :string, description: "Coherent synthesized reality", required: true, default: nil},
        %{name: :reality_mechanics, type: :string, description: "Underlying reality mechanics", required: true, default: nil},
        %{name: :consistency_check, type: :string, description: "Internal consistency analysis", required: true, default: nil},
        %{name: :reality_implications, type: :string, description: "Implications of synthesized reality", required: false, default: nil}
      ]
    )
  end

  def dimensional_analysis do
    new("dimensional_analysis",
      input_fields: [
        %{name: :dimensional_context, type: :string, description: "Context requiring dimensional analysis", required: true, default: nil},
        %{name: :dimensional_framework, type: :string, description: "Dimensional framework to use", required: false, default: nil},
        %{name: :analysis_objectives, type: :string, description: "Objectives of dimensional analysis", required: false, default: nil}
      ],
      output_fields: [
        %{name: :dimensional_structure, type: :string, description: "Dimensional structure analysis", required: true, default: nil},
        %{name: :cross_dimensional_effects, type: :string, description: "Effects across dimensions", required: true, default: nil},
        %{name: :dimensional_interactions, type: :string, description: "Inter-dimensional interactions", required: true, default: nil},
        %{name: :higher_order_implications, type: :string, description: "Higher-order dimensional implications", required: false, default: nil}
      ]
    )
  end

  def temporal_reasoning do
    new("temporal_reasoning",
      input_fields: [
        %{name: :temporal_scenario, type: :string, description: "Scenario involving temporal reasoning", required: true, default: nil},
        %{name: :time_constraints, type: :string, description: "Temporal constraints and boundaries", required: false, default: nil},
        %{name: :causal_relationships, type: :string, description: "Known causal relationships", required: false, default: nil}
      ],
      output_fields: [
        %{name: :temporal_analysis, type: :string, description: "Analysis of temporal relationships", required: true, default: nil},
        %{name: :causality_chains, type: :string, description: "Causal chains through time", required: true, default: nil},
        %{name: :temporal_paradoxes, type: :string, description: "Potential temporal paradoxes", required: true, default: nil},
        %{name: :timeline_implications, type: :string, description: "Implications for timeline integrity", required: false, default: nil}
      ]
    )
  end

  def quantum_consciousness do
    new("quantum_consciousness",
      input_fields: [
        %{name: :consciousness_question, type: :string, description: "Question about quantum consciousness", required: true, default: nil},
        %{name: :quantum_framework, type: :string, description: "Quantum mechanical framework", required: false, default: nil},
        %{name: :consciousness_theory, type: :string, description: "Consciousness theory to integrate", required: false, default: nil}
      ],
      output_fields: [
        %{name: :quantum_consciousness_model, type: :string, description: "Quantum consciousness model", required: true, default: nil},
        %{name: :quantum_effects, type: :string, description: "Quantum effects on consciousness", required: true, default: nil},
        %{name: :measurement_problem, type: :string, description: "Consciousness and measurement problem", required: true, default: nil},
        %{name: :empirical_predictions, type: :string, description: "Testable empirical predictions", required: false, default: nil}
      ]
    )
  end

  def synthetic_biology do
    new("synthetic_biology",
      input_fields: [
        %{name: :biological_design_goal, type: :string, description: "Biological system design goal", required: true, default: nil},
        %{name: :available_components, type: :string, description: "Available biological components", required: false, default: nil},
        %{name: :design_constraints, type: :string, description: "Design and safety constraints", required: false, default: nil}
      ],
      output_fields: [
        %{name: :synthetic_design, type: :string, description: "Synthetic biological system design", required: true, default: nil},
        %{name: :component_integration, type: :string, description: "Integration of biological components", required: true, default: nil},
        %{name: :functionality_prediction, type: :string, description: "Predicted system functionality", required: true, default: nil},
        %{name: :biosafety_assessment, type: :string, description: "Biosafety and ethical considerations", required: false, default: nil}
      ]
    )
  end

  def memetic_engineering do
    new("memetic_engineering",
      input_fields: [
        %{name: :memetic_goal, type: :string, description: "Goal of memetic engineering", required: true, default: nil},
        %{name: :target_population, type: :string, description: "Target population for meme spread", required: false, default: nil},
        %{name: :cultural_context, type: :string, description: "Cultural and social context", required: false, default: nil}
      ],
      output_fields: [
        %{name: :meme_design, type: :string, description: "Engineered meme structure", required: true, default: nil},
        %{name: :transmission_strategy, type: :string, description: "Meme transmission strategy", required: true, default: nil},
        %{name: :evolutionary_stability, type: :string, description: "Meme evolutionary stability", required: true, default: nil},
        %{name: :ethical_implications, type: :string, description: "Ethical implications of meme engineering", required: false, default: nil}
      ]
    )
  end

  def collective_intelligence do
    new("collective_intelligence",
      input_fields: [
        %{name: :collective_challenge, type: :string, description: "Challenge for collective intelligence", required: true, default: nil},
        %{name: :group_composition, type: :string, description: "Composition of the collective", required: false, default: nil},
        %{name: :intelligence_mechanisms, type: :string, description: "Mechanisms for collective intelligence", required: false, default: nil}
      ],
      output_fields: [
        %{name: :collective_solution, type: :string, description: "Collective intelligence solution", required: true, default: nil},
        %{name: :emergence_analysis, type: :string, description: "Analysis of emergent intelligence", required: true, default: nil},
        %{name: :coordination_mechanisms, type: :string, description: "Coordination and decision mechanisms", required: true, default: nil},
        %{name: :intelligence_amplification, type: :string, description: "Strategies for intelligence amplification", required: false, default: nil}
      ]
    )
  end

  def emergent_behavior do
    new("emergent_behavior",
      input_fields: [
        %{name: :system_description, type: :string, description: "System showing emergent behavior", required: true, default: nil},
        %{name: :component_interactions, type: :string, description: "Component interactions", required: false, default: nil},
        %{name: :emergence_conditions, type: :string, description: "Conditions for emergence", required: false, default: nil}
      ],
      output_fields: [
        %{name: :emergent_properties, type: :string, description: "Identified emergent properties", required: true, default: nil},
        %{name: :emergence_mechanisms, type: :string, description: "Mechanisms driving emergence", required: true, default: nil},
        %{name: :predictability_analysis, type: :string, description: "Predictability of emergent behavior", required: true, default: nil},
        %{name: :control_strategies, type: :string, description: "Strategies for guiding emergence", required: false, default: nil}
      ]
    )
  end

  def paradigm_shifting do
    new("paradigm_shifting",
      input_fields: [
        %{name: :current_paradigm, type: :string, description: "Current paradigm or worldview", required: true, default: nil},
        %{name: :paradigm_tensions, type: :string, description: "Tensions within current paradigm", required: false, default: nil},
        %{name: :catalytic_factors, type: :string, description: "Factors that could drive paradigm shift", required: false, default: nil}
      ],
      output_fields: [
        %{name: :paradigm_shift_analysis, type: :string, description: "Analysis of potential paradigm shift", required: true, default: nil},
        %{name: :new_paradigm_features, type: :string, description: "Features of emerging paradigm", required: true, default: nil},
        %{name: :transition_dynamics, type: :string, description: "Dynamics of paradigm transition", required: true, default: nil},
        %{name: :resistance_factors, type: :string, description: "Factors resisting paradigm change", required: false, default: nil}
      ]
    )
  end

  @doc """
  Generate a prompt template from the signature.
  """
  def to_prompt(signature, examples \\ []) do
    sections = [
      instruction_section(signature),
      format_instruction_section(signature),
      field_descriptions_section(signature),
      examples_section(examples, signature),
      input_section(signature)
    ]

    sections
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
  end

  @doc """
  Validate inputs against the signature.
  """
  def validate_inputs(signature, inputs) do
    required_fields =
      signature.input_fields
      |> Enum.filter(& &1.required)
      |> Enum.map(& &1.name)

    missing_fields = required_fields -- Map.keys(inputs)

    case missing_fields do
      [] -> :ok
      missing -> {:error, {:missing_fields, missing}}
    end
  end

  @doc """
  Parse outputs according to the signature.
  """
  def parse_outputs(signature, text) do
    output_fields = signature.output_fields

    outputs =
      output_fields
      |> Enum.reduce(%{}, fn field, acc ->
        case extract_field_value(text, field) do
          {:ok, value} ->
            case validate_field_value(value, field) do
              {:ok, validated_value} -> Map.put(acc, field.name, validated_value)
              {:error, _} -> acc
            end

          :error ->
            acc
        end
      end)

    # Validate the complete output structure
    case validate_output_structure(outputs, signature) do
      :ok -> outputs
      {:error, _reason} = error -> error
    end
  end

  defp instruction_section(%{instructions: nil}), do: nil

  defp instruction_section(%{instructions: instructions}) do
    "Instructions: #{instructions}"
  end

  defp format_instruction_section(signature) do
    output_format =
      signature.output_fields
      |> Enum.map(fn field ->
        "#{String.capitalize(Atom.to_string(field.name))}: [your #{field.description}]"
      end)
      |> Enum.join("\n")

    "Follow this exact format for your response:\n#{output_format}"
  end

  defp field_descriptions_section(signature) do
    input_desc = describe_fields("Input", signature.input_fields)
    output_desc = describe_fields("Output", signature.output_fields)

    [input_desc, output_desc]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
  end

  defp describe_fields(_label, []), do: nil

  defp describe_fields(label, fields) do
    field_lines =
      fields
      |> Enum.map(fn field ->
        "- #{field.name}: #{field.description}"
      end)
      |> Enum.join("\n")

    "#{label} Fields:\n#{field_lines}"
  end

  defp examples_section([], _signature), do: nil

  defp examples_section(examples, signature) do
    example_text =
      examples
      |> Enum.with_index(1)
      |> Enum.map(fn {example, idx} ->
        format_example(example, signature, idx)
      end)
      |> Enum.join("\n\n")

    "Examples:\n\n#{example_text}"
  end

  defp format_example(example, signature, idx) do
    input_text = format_fields(example, signature.input_fields)
    output_text = format_fields(example, signature.output_fields)

    "Example #{idx}:\n#{input_text}\n#{output_text}"
  end

  defp format_fields(example, fields) do
    fields
    |> Enum.map(fn field ->
      value = Map.get(example.attrs || example, field.name, "")
      "#{String.capitalize(Atom.to_string(field.name))}: #{value}"
    end)
    |> Enum.join("\n")
  end

  defp input_section(signature) do
    placeholder_inputs =
      signature.input_fields
      |> Enum.map(fn field ->
        "#{String.capitalize(Atom.to_string(field.name))}: [input]"
      end)
      |> Enum.join("\n")

    output_labels =
      signature.output_fields
      |> Enum.map(fn field ->
        "#{String.capitalize(Atom.to_string(field.name))}:"
      end)
      |> Enum.join("\n")

    "#{placeholder_inputs}\n#{output_labels}"
  end

  defp extract_field_value(text, field) do
    field_name = String.capitalize(Atom.to_string(field.name))
    
    # Try multiple patterns to be more flexible
    patterns = [
      ~r/#{field_name}:\s*(.+?)(?=\n[A-Z][a-z]*:|$)/s,  # Original pattern
      ~r/#{field_name}:\s*(.+)/,                          # Simple pattern to end of line
      ~r/#{field_name}\s*:\s*(.+)/,                       # Allow spaces around colon
      ~r/#{field_name}\s*(.+)/                            # Without colon
    ]
    
    result = Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, text, capture: :all_but_first) do
        [value] -> {:ok, String.trim(value)}
        nil -> nil
      end
    end)
    
    result || :error
  end

  defp validate_field_value(value, field) do
    case field.type do
      :string ->
        if is_binary(value), do: {:ok, value}, else: {:error, :invalid_string}

      :number ->
        case Float.parse(value) do
          {num, ""} ->
            {:ok, num}

          {num, _} ->
            {:ok, num}

          :error ->
            case Integer.parse(value) do
              {num, ""} -> {:ok, num}
              _ -> {:error, :invalid_number}
            end
        end

      :boolean ->
        case String.downcase(String.trim(value)) do
          "true" -> {:ok, true}
          "false" -> {:ok, false}
          "yes" -> {:ok, true}
          "no" -> {:ok, false}
          "1" -> {:ok, true}
          "0" -> {:ok, false}
          _ -> {:error, :invalid_boolean}
        end

      :json ->
        try do
          {:ok, Jason.decode!(value)}
        rescue
          _ -> {:error, :invalid_json}
        end

      :code ->
        case validate_elixir_code(value) do
          :ok -> {:ok, value}
          {:error, reason} -> {:error, {:invalid_code, reason}}
        end

      # Default: accept as string
      _ ->
        {:ok, value}
    end
  end

  defp validate_output_structure(outputs, signature) do
    required_fields =
      signature.output_fields
      |> Enum.filter(& &1.required)
      |> Enum.map(& &1.name)

    missing_fields = required_fields -- Map.keys(outputs)

    case missing_fields do
      [] -> :ok
      missing -> {:error, {:missing_required_outputs, missing}}
    end
  end

  defp validate_elixir_code(code) do
    try do
      Code.string_to_quoted!(code)
      :ok
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  # Parse signature string like "func_name(input1: type, input2: type) -> output1: type, output2: type"
  defp parse_signature_string(signature_string) do
    # Clean up the string
    clean_string = signature_string |> String.trim() |> String.replace(~r/\s+/, " ")
    
    # Split on "->" to get inputs and outputs
    case String.split(clean_string, "->", parts: 2) do
      [input_part, output_part] ->
        with {:ok, {name, input_fields}} <- parse_input_part(String.trim(input_part)),
             {:ok, output_fields} <- parse_output_part(String.trim(output_part)) do
          {:ok, {name, input_fields, output_fields}}
        else
          error -> error
        end
      
      [input_part] ->
        # No outputs specified
        case parse_input_part(String.trim(input_part)) do
          {:ok, {name, input_fields}} -> {:ok, {name, input_fields, []}}
          error -> error
        end
      
      _ ->
        {:error, "Multiple '->' found in signature"}
    end
  end

  defp parse_input_part(input_part) do
    # Extract function name and parameters
    case Regex.run(~r/^(\w+)\s*\((.*)\)$/, input_part) do
      [_, name, params_str] ->
        case parse_fields(params_str) do
          {:ok, fields} -> {:ok, {name, fields}}
          error -> error
        end
      
      nil ->
        {:error, "Invalid input format - expected 'function_name(params)'"}
    end
  end

  defp parse_output_part(output_part) do
    parse_fields(output_part)
  end

  defp parse_fields(""), do: {:ok, []}
  
  defp parse_fields(fields_str) do
    fields_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reduce_while({:ok, []}, fn field_str, {:ok, acc} ->
      case parse_single_field(field_str) do
        {:ok, field} -> {:cont, {:ok, [field | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, fields} -> {:ok, Enum.reverse(fields)}
      error -> error
    end
  end

  defp parse_single_field(field_str) do
    case String.split(field_str, ":", parts: 2) do
      [name, type] ->
        name = name |> String.trim() |> String.to_atom()
        type = type |> String.trim() |> normalize_type()
        
        {:ok, %{
          name: name,
          type: type,
          description: humanize_field_name(name),
          required: true,
          default: nil
        }}
      
      _ ->
        {:error, "Invalid field format - expected 'name: type'"}
    end
  end

  defp normalize_type("str"), do: :string
  defp normalize_type("string"), do: :string
  defp normalize_type("int"), do: :number
  defp normalize_type("integer"), do: :number
  defp normalize_type("float"), do: :number
  defp normalize_type("number"), do: :number
  defp normalize_type("bool"), do: :boolean
  defp normalize_type("boolean"), do: :boolean
  defp normalize_type("json"), do: :json
  defp normalize_type("code"), do: :code
  defp normalize_type(type), do: String.to_atom(type)

  defp humanize_field_name(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
