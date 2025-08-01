defmodule Dspy do
  @moduledoc """
  Elixir implementation of DSPy - a framework for algorithmically optimizing LM prompts and weights.

  DSPy provides a unified interface for composing LM programs with automatic optimization.

  ## Core Components

  - `Dspy.Signature` - Define typed input/output interfaces for LM calls
  - `Dspy.Module` - Composable building blocks for LM programs  
  - `Dspy.Predict` - Basic prediction modules
  - `Dspy.ChainOfThought` - Step-by-step reasoning
  - `Dspy.ChainOfContinuousThought` - Latent space reasoning (COCONUT)
  - `Dspy.LM` - Language model client abstraction
  - `Dspy.Example` - Training examples and data structures
  - `Dspy.Teleprompt` - Prompt optimization algorithms (MiPro, SIMBA, etc.)

  ## Advanced Reasoning Modules

  - `Dspy.SelfConsistency` - Multiple sampling for consistent answers
  - `Dspy.MultiStep` - Sequential multi-step problem solving
  - `Dspy.Reflection` - Self-reflection and answer revision
  - `Dspy.ProgramOfThoughts` - Reasoning combined with executable code
  - `Dspy.SelfCorrectingCoT` - Chain of thought with self-correction
  - `Dspy.TreeOfThoughts` - Tree-structured reasoning exploration
  - `Dspy.AdaptiveBacktracking` - Intelligent backtracking with memory
  - `Dspy.BackwardChaining` - Goal-driven backward reasoning
  - `Dspy.VerificationBehavior` - Systematic solution verification

  ## Enhanced Vision and Sequential Solving (NEW)

  - `Dspy.EnhancedSignature` - Vision-enabled signatures with intelligent content chunking (no truncation)
  - `Dspy.SequentialVisionSolver` - Advanced sequential problem solver with vision abstraction
  - Integrated evaluation metrics from evalscompany framework
  - Multi-signal reward system for nuanced training
  - Support for CBLE (Customs Broker License Examination) evaluation patterns

  ## Novel System Generation and Learning

  - `Dspy.NovelSystemGenerator` - Dynamic generation of novel reasoning systems
  - `Dspy.TrainingDataStorage` - Comprehensive storage and analysis of experiment data
  - `Dspy.ExperimentalFramework` - Orchestrates novel system generation and learning cycles

  ## Scientific Experiment Management (ENHANCED)

  - `Dspy.ExperimentJournal` - Comprehensive scientific experiment tracking and analysis
  - `Dspy.AdaptiveExperimentFramework` - Advanced experiment framework with real-time adaptation
  - `Dspy.ScientificInquiryWorkflow` - Complete end-to-end research pipeline from hypothesis to publication
  - `Dspy.QuantumEnhancedResearchFramework` - Revolutionary quantum-enhanced research with advanced AI
  - `Dspy.ConsciousnessEmergenceDetector` - Advanced consciousness detection and ethical management
  - Hypothesis-driven research with statistical validation
  - Knowledge graph integration for concept learning
  - Real-time monitoring with live dashboards
  - Collaborative research workflows and peer review
  - Automated publication preparation and LaTeX generation
  - Multi-stage research pipeline with quality checkpoints
  - Cross-cultural validation and replication protocols
  - Theory building and knowledge integration systems
  - Quantum superposition hypothesis testing and optimization
  - Consciousness emergence detection with ethical protocols
  - Advanced mathematical frameworks (topology, category theory, information geometry)
  - Swarm intelligence collective problem solving
  - Autonomous research agents with recursive self-improvement
  - Research singularity risk assessment and containment

  ## Quick Start

      # Configure language model
      Dspy.configure(lm: %Dspy.LM.OpenAI{model: "gpt-4.1"})

      # Define signature
      defmodule QA do
        use Dspy.Signature
        input_field :question, :string, "Question to answer"
        output_field :answer, :string, "Answer to the question"
      end

      # Create and use module
      predict = Dspy.Predict.new(QA)
      result = Dspy.Module.forward(predict, %{question: "What is 2+2?"})

      # Use COCONUT for advanced latent reasoning
      coconut = Dspy.ChainOfContinuousThought.new(QA,
        num_continuous_thoughts: 3,
        latent_mode_enabled: true
      )
      {:ok, latent_result} = Dspy.Module.forward(coconut, %{question: "What is 2+2?"})

      # For complex problems, use novel system generation
      framework = Dspy.ExperimentalFramework.new(QA)
      {:ok, novel_result} = Dspy.Module.forward(framework, %{
        question: "Design a novel approach to solve climate change"
      })

  ## Enhanced Vision and Sequential Solving

      # Create vision-enabled signature (no truncation)
      vision_signature = Dspy.EnhancedSignature.new("VisionProblem",
        input_fields: [
          %{name: :problem, type: :string, description: "Problem description"},
          %{name: :image, type: :image, description: "Visual data", vision_enabled: true}
        ],
        output_fields: [
          %{name: :analysis, type: :vision_text, description: "Visual analysis"},
          %{name: :solution, type: :string, description: "Complete solution"}
        ],
        vision_enabled: true,
        max_content_length: 100_000  # No truncation
      )

      # Create sequential solver with advanced evaluation
      solver = Dspy.SequentialVisionSolver.new(vision_signature,
        vision_enabled: true,
        evaluation_config: %{
          enable_step_scoring: true,
          enable_reasoning_analysis: true,
          enable_vision_assessment: true
        }
      )

      # Solve with image and text
      {:ok, result} = Dspy.Module.forward(solver, %{
        problem: "Analyze this engineering diagram and calculate the stress distribution",
        image: "data:image/png;base64,..."
      })

      # Access comprehensive evaluation metrics
      metrics = result.attrs.overall_metrics
      # %{reasoning_coherence: 0.85, vision_integration: 0.92, ...}

  ## Teleprompt Optimization

      # Optimize programs using teleprompts
      alias Dspy.Teleprompt.{BootstrapFewShot, MIPROv2, SIMBA}
      
      # BootstrapFewShot - Automatic few-shot learning
      bootstrap = BootstrapFewShot.new(metric: &Dspy.Metrics.exact_match/2)
      {:ok, optimized} = Dspy.Teleprompt.compile(bootstrap, predict, trainset)
      
      # MIPROv2 - Advanced instruction + example optimization  
      mipro = MIPROv2.new(metric: &Dspy.Metrics.f1_score/2, auto: "medium")
      {:ok, optimized} = Dspy.Teleprompt.compile(mipro, predict, trainset)
      
      # SIMBA - Stochastic iterative optimization
      simba = SIMBA.new(metric: &Dspy.Metrics.accuracy/2, max_steps: 8)
      {:ok, optimized} = Dspy.Teleprompt.compile(simba, predict, trainset)
      
      # Ensemble - Multiple program combination
      ensemble = Dspy.Teleprompt.Ensemble.new(
        size: 5, 
        base_teleprompt: :bootstrap_few_shot,
        combination_strategy: :majority_vote
      )
      {:ok, ensemble_program} = Dspy.Teleprompt.compile(ensemble, predict, trainset)
  """

  alias Dspy.{Settings, Example, Prediction}

  @type dspy_config :: [
    lm: module(),
    max_tokens: pos_integer(),
    temperature: float(),
    cache: boolean()
  ]

  @type settings :: %{
    lm: module(),
    max_tokens: pos_integer(),
    temperature: float(),
    cache: boolean(),
    metadata: map()
  }

  @doc """
  Configure global DSPy settings.

  ## Options

  - `:lm` - Language model client (required)
  - `:max_tokens` - Maximum tokens per generation (default: 2048)  
  - `:temperature` - Sampling temperature (default: 0.0)
  - `:cache` - Enable response caching (default: true)

  ## Examples

      Dspy.configure(
        lm: %Dspy.LM.OpenAI{model: "gpt-4.1", api_key: "sk-..."},
        max_tokens: 4096,
        temperature: 0.1,
        cache: true
      )

  """
  @spec configure(dspy_config()) :: :ok | {:error, term()}
  def configure(opts \\ []) do
    Settings.configure(opts)
  end

  @doc """
  Get current DSPy configuration.

  ## Returns

  Returns the current global DSPy settings as a map.

  ## Examples

      settings = Dspy.settings()
      # %{lm: %Dspy.LM.OpenAI{...}, max_tokens: 2048, ...}

  """
  @spec settings() :: settings()
  def settings do
    Settings.get()
  end

  @doc """
  Create a new Example with the given attributes.

  Examples are used for training and evaluation of DSPy modules.

  ## Parameters

  - `attrs` - Map of attributes for the example

  ## Examples

      example = Dspy.example(%{
        question: "What is 2+2?", 
        answer: "4"
      })

  """
  @spec example(map()) :: Example.t()
  def example(attrs \\ %{}) do
    Example.new(attrs)
  end

  @doc """
  Create a new Prediction with the given attributes.

  Predictions represent the output of DSPy modules.

  ## Parameters

  - `attrs` - Map of prediction attributes and metadata

  ## Examples

      prediction = Dspy.prediction(%{
        answer: "The capital is Paris",
        confidence: 0.95
      })

  """
  @spec prediction(map()) :: Prediction.t()
  def prediction(attrs \\ %{}) do
    Prediction.new(attrs)
  end
end
