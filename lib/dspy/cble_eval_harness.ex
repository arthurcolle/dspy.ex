defmodule Dspy.CBLEEvalHarness do
  @moduledoc """
  Comprehensive CBLE (Customs Broker License Examination) Evaluation Harness

  This module provides a complete evaluation framework for testing DSPy agents
  across multiple GPT models (gpt-4.1, gpt-4.1-mini, gpt-4.1-nano) on CBLE exams.

  Features:
  - PDF content extraction with image handling
  - Multi-modal question processing (text + images)
  - Cross-model performance comparison
  - Comprehensive evaluation metrics
  - Results aggregation and analysis
  """

  require Logger

  defstruct [
    :exam_data_path,
    :output_path,
    :models,
    :exam_dates,
    :categories,
    :max_questions,
    :evaluation_config,
    :pdf_processor,
    :content_cache
  ]

  @type model_config :: %{
          name: String.t(),
          model_id: String.t(),
          temperature: float(),
          max_tokens: integer(),
          cost_per_token: float()
        }

  @type exam_question :: %{
          question_id: String.t(),
          question_text: String.t(),
          images: [binary()],
          options: [String.t()],
          correct_answer: String.t(),
          category: String.t(),
          page_number: integer(),
          difficulty: atom(),
          has_images: boolean()
        }

  @type agent_response :: %{
          model: String.t(),
          question_id: String.t(),
          answer: String.t(),
          reasoning: String.t(),
          confidence: float(),
          execution_time: float(),
          tokens_used: integer(),
          cost: float(),
          success: boolean(),
          error: String.t() | nil
        }

  @type evaluation_result :: %{
          model: String.t(),
          exam_date: String.t(),
          total_questions: integer(),
          correct_answers: integer(),
          accuracy: float(),
          category_breakdown: map(),
          performance_metrics: map(),
          cost_analysis: map(),
          timing_analysis: map()
        }

  @doc """
  Create a new CBLE evaluation harness.
  """
  def new(opts \\ []) do
    %__MODULE__{
      exam_data_path:
        Keyword.get(opts, :exam_data_path, "/Users/agent/evalscompany/cble_dataset"),
      output_path: Keyword.get(opts, :output_path, "/Users/agent/dspy/cble_results"),
      models: Keyword.get(opts, :models, default_models()),
      exam_dates: Keyword.get(opts, :exam_dates, ["2023-Oct", "2023-Apr", "2024-Apr"]),
      # nil = all categories
      categories: Keyword.get(opts, :categories, nil),
      # nil = all questions
      max_questions: Keyword.get(opts, :max_questions, nil),
      evaluation_config: Keyword.get(opts, :evaluation_config, default_evaluation_config()),
      pdf_processor: Keyword.get(opts, :pdf_processor, :python_based),
      content_cache: %{}
    }
  end

  @doc """
  Run the complete CBLE evaluation across all configured models and exams.
  """
  def run_evaluation(harness) do
    Logger.info("Starting CBLE evaluation harness")

    with {:ok, _} <- setup_output_directory(harness),
         {:ok, exam_data} <- extract_all_exam_data(harness),
         {:ok, questions} <- process_questions(harness, exam_data),
         {:ok, results} <- evaluate_all_models(harness, questions),
         {:ok, analysis} <- analyze_results(harness, results),
         {:ok, _} <- generate_reports(harness, results, analysis) do
      Logger.info("CBLE evaluation completed successfully")
      {:ok, %{results: results, analysis: analysis}}
    else
      {:error, reason} ->
        Logger.error("CBLE evaluation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Extract content from CBLE PDF files including images.
  """
  def extract_pdf_content(harness, pdf_path) do
    case File.exists?(pdf_path) do
      false ->
        {:error, {:file_not_found, pdf_path}}

      true ->
        case harness.pdf_processor do
          :python_based -> extract_with_python(pdf_path)
          :elixir_based -> extract_with_elixir(pdf_path)
          _ -> {:error, :unsupported_processor}
        end
    end
  end

  @doc """
  Process a single question with all configured models.
  """
  def evaluate_question(harness, question) do
    Logger.debug("Evaluating question #{question.question_id}")

    results =
      Enum.map(harness.models, fn model ->
        Task.async(fn ->
          evaluate_question_with_model(harness, question, model)
        end)
      end)
      # 30 second timeout per question
      |> Task.await_many(30_000)

    {:ok, results}
  end

  # Private implementation functions

  defp default_models do
    [
      %{
        name: "GPT-4.1",
        model_id: "gpt-4.1",
        temperature: 0.1,
        max_tokens: 2000,
        cost_per_token: 0.00003
      },
      %{
        name: "GPT-4.1-Mini",
        model_id: "gpt-4.1-mini",
        temperature: 0.1,
        max_tokens: 2000,
        cost_per_token: 0.00001
      },
      %{
        name: "GPT-4.1-Nano",
        model_id: "gpt-4.1-nano",
        temperature: 0.1,
        max_tokens: 1500,
        cost_per_token: 0.000005
      }
    ]
  end

  defp default_evaluation_config do
    %{
      enable_reasoning_analysis: true,
      enable_confidence_calibration: true,
      enable_category_analysis: true,
      enable_difficulty_analysis: true,
      enable_cost_analysis: true,
      enable_vision_analysis: true,
      save_intermediate_results: true,
      parallel_evaluation: true,
      max_retries: 2
    }
  end

  defp setup_output_directory(harness) do
    timestamp = DateTime.utc_now() |> DateTime.to_string() |> String.replace(~r/[^\d]/, "")
    full_output_path = Path.join(harness.output_path, "cble_eval_#{timestamp}")

    with :ok <- File.mkdir_p(full_output_path),
         :ok <- File.mkdir_p(Path.join(full_output_path, "raw_results")),
         :ok <- File.mkdir_p(Path.join(full_output_path, "analysis")),
         :ok <- File.mkdir_p(Path.join(full_output_path, "reports")) do
      updated_harness = %{harness | output_path: full_output_path}
      {:ok, updated_harness}
    else
      {:error, reason} -> {:error, {:setup_failed, reason}}
    end
  end

  defp extract_all_exam_data(harness) do
    Logger.info("Extracting exam data from #{harness.exam_data_path}")

    exam_data =
      Enum.reduce(harness.exam_dates, %{}, fn exam_date, acc ->
        case extract_exam_data_for_date(harness, exam_date) do
          {:ok, data} ->
            Map.put(acc, exam_date, data)

          {:error, reason} ->
            Logger.warning("Failed to extract data for #{exam_date}: #{inspect(reason)}")
            acc
        end
      end)

    if map_size(exam_data) > 0 do
      {:ok, exam_data}
    else
      {:error, :no_exam_data_extracted}
    end
  end

  defp extract_exam_data_for_date(harness, exam_date) do
    exam_base_path = Path.join([harness.exam_data_path, "past_exams_and_keys"])
    exam_file = Path.join([exam_base_path, "pdf", "#{exam_date}-exam.pdf"])
    key_file = Path.join([exam_base_path, "txt", "#{exam_date}-key.txt"])

    with {:ok, exam_content} <- extract_pdf_content(harness, exam_file),
         {:ok, answer_key} <- extract_answer_key(key_file) do
      data = %{
        exam_date: exam_date,
        exam_content: exam_content,
        answer_key: answer_key,
        exam_file: exam_file,
        key_file: key_file
      }

      {:ok, data}
    else
      error -> error
    end
  end

  defp extract_with_python(pdf_path) do
    # Create Python script for PDF extraction with image support
    python_script = create_pdf_extraction_script()
    script_path = "/tmp/pdf_extractor_#{System.unique_integer()}.py"

    try do
      File.write!(script_path, python_script)

      # Run Python script
      {output, exit_code} = System.cmd("python3", [script_path, pdf_path], stderr_to_stdout: true)

      case exit_code do
        0 ->
          case Jason.decode(output) do
            {:ok, data} -> {:ok, process_extracted_data(data)}
            {:error, _} -> {:error, {:invalid_json, output}}
          end

        _ ->
          {:error, {:python_error, output}}
      end
    after
      File.rm(script_path)
    end
  end

  defp create_pdf_extraction_script do
    """
    #!/usr/bin/env python3
    import sys
    import json
    import base64
    from pathlib import Path

    try:
        import PyPDF2
        import fitz  # PyMuPDF for image extraction
        from PIL import Image
        import io
    except ImportError as e:
        print(json.dumps({"error": f"Missing dependency: {e}"}))
        sys.exit(1)

    def extract_pdf_content(pdf_path):
        content = {
            "pages": [],
            "metadata": {
                "total_pages": 0,
                "has_images": False,
                "extraction_method": "python_pymupdf"
            }
        }
        
        try:
            # Open PDF with PyMuPDF for comprehensive extraction
            pdf_document = fitz.open(pdf_path)
            content["metadata"]["total_pages"] = pdf_document.page_count
            
            for page_num in range(pdf_document.page_count):
                page = pdf_document[page_num]
                
                # Extract text
                text = page.get_text()
                
                # Extract images
                images = []
                image_list = page.get_images()
                
                for img_index, img in enumerate(image_list):
                    try:
                        xref = img[0]
                        pix = fitz.Pixmap(pdf_document, xref)
                        
                        if pix.n < 5:  # GRAY or RGB
                            img_data = pix.tobytes("png")
                            img_b64 = base64.b64encode(img_data).decode()
                            
                            images.append({
                                "image_id": f"page_{page_num + 1}_img_{img_index + 1}",
                                "data": img_b64,
                                "width": pix.width,
                                "height": pix.height,
                                "format": "png"
                            })
                            content["metadata"]["has_images"] = True
                        
                        pix = None
                    except Exception as e:
                        print(f"Error extracting image {img_index}: {e}", file=sys.stderr)
                
                page_content = {
                    "page_number": page_num + 1,
                    "text": text,
                    "images": images,
                    "has_images": len(images) > 0,
                    "char_count": len(text)
                }
                
                content["pages"].append(page_content)
            
            pdf_document.close()
            return content
            
        except Exception as e:
            return {"error": f"PDF extraction failed: {e}"}

    if __name__ == "__main__":
        if len(sys.argv) != 2:
            print(json.dumps({"error": "Usage: python script.py <pdf_path>"}))
            sys.exit(1)
        
        pdf_path = sys.argv[1]
        result = extract_pdf_content(pdf_path)
        print(json.dumps(result, indent=2))
    """
  end

  defp extract_with_elixir(pdf_path) do
    # Fallback: Simple text extraction using pdftotext if available
    case System.cmd("pdftotext", [pdf_path, "-"], stderr_to_stdout: true) do
      {output, 0} ->
        content = %{
          pages: [
            %{
              page_number: 1,
              text: output,
              images: [],
              has_images: false,
              char_count: String.length(output)
            }
          ],
          metadata: %{
            total_pages: 1,
            has_images: false,
            extraction_method: "pdftotext"
          }
        }

        {:ok, content}

      {error, _} ->
        {:error, {:pdftotext_failed, error}}
    end
  end

  defp process_extracted_data(data) do
    case Map.get(data, "error") do
      nil -> data
      error -> throw({:extraction_error, error})
    end
  end

  defp extract_answer_key(key_file_path) do
    case File.read(key_file_path) do
      {:ok, content} -> {:ok, parse_answer_key(content)}
      {:error, reason} -> {:error, {:key_file_error, reason}}
    end
  end

  defp parse_answer_key(content) do
    # Parse answer key format - looking for "Answer X" patterns
    lines =
      content
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    # Find all "Answer X" lines
    answers =
      lines
      |> Enum.filter(&String.match?(&1, ~r/^Answer\s+[A-E]/i))
      |> Enum.map(fn line ->
        case Regex.run(~r/^Answer\s+([A-E])/i, line) do
          [_, answer] -> String.upcase(answer)
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    # Map answers to question numbers (1-indexed)
    answers
    |> Enum.with_index(1)
    |> Enum.reduce(%{}, fn {answer, idx}, acc ->
      Map.put(acc, idx, answer)
    end)
  end

  defp process_questions(harness, exam_data) do
    Logger.info("Processing questions from exam data")

    all_questions =
      Enum.flat_map(exam_data, fn {exam_date, data} ->
        extract_questions_from_exam(harness, exam_date, data)
      end)

    # Filter by categories if specified
    filtered_questions =
      if harness.categories do
        Enum.filter(all_questions, fn q -> q.category in harness.categories end)
      else
        all_questions
      end

    # Limit number of questions if specified
    final_questions =
      if harness.max_questions do
        Enum.take(filtered_questions, harness.max_questions)
      else
        filtered_questions
      end

    Logger.info("Processed #{length(final_questions)} questions")
    {:ok, final_questions}
  end

  defp extract_questions_from_exam(harness, exam_date, exam_data) do
    pages = exam_data.exam_content["pages"] || []
    answer_key = exam_data.answer_key

    Enum.flat_map(pages, fn page ->
      extract_questions_from_page(harness, exam_date, page, answer_key)
    end)
  end

  defp extract_questions_from_page(_harness, exam_date, page, answer_key) do
    text = page["text"] || ""
    images = page["images"] || []
    page_number = page["page_number"] || 0

    # Extract questions using pattern matching
    question_patterns = [
      # Numbered questions
      ~r/(\d+)\.\s*(.+?)(?=\d+\.|$)/s,
      # "Question N" format
      ~r/Question\s+(\d+)[:\.]?\s*(.+?)(?=Question\s+\d+|$)/si
    ]

    questions =
      Enum.flat_map(question_patterns, fn pattern ->
        Regex.scan(pattern, text)
        |> Enum.map(fn [_, num_str, question_text] ->
          question_num = String.to_integer(num_str)
          correct_answer = Map.get(answer_key, question_num)

          %{
            question_id: "#{exam_date}_q#{question_num}",
            question_text: String.trim(question_text),
            images: process_page_images(images),
            options: extract_options(question_text),
            correct_answer: correct_answer,
            category: determine_category(question_text),
            page_number: page_number,
            difficulty: determine_difficulty(question_text),
            has_images: length(images) > 0,
            exam_date: exam_date
          }
        end)
      end)

    # Filter out questions without answers in the key
    Enum.filter(questions, fn q -> q.correct_answer != nil end)
  end

  defp process_page_images(images) do
    Enum.map(images, fn image ->
      %{
        id: image["image_id"],
        data: "data:image/png;base64,#{image["data"]}",
        width: image["width"],
        height: image["height"],
        format: image["format"]
      }
    end)
  end

  defp extract_options(question_text) do
    # Extract multiple choice options A, B, C, D, E
    option_pattern = ~r/\b([A-E])\.\s*([^\n]+)/

    Regex.scan(option_pattern, question_text)
    |> Enum.map(fn [_, letter, text] ->
      "#{letter}. #{String.trim(text)}"
    end)
  end

  defp determine_category(question_text) do
    # Basic category determination based on keywords
    text_lower = String.downcase(question_text)

    cond do
      String.contains?(text_lower, ["entry", "classification", "tariff", "schedule"]) ->
        "Classification"

      String.contains?(text_lower, ["valuation", "transaction", "value", "appraisal"]) ->
        "Valuation"

      String.contains?(text_lower, ["origin", "country", "nafta", "certificate"]) ->
        "Origin"

      String.contains?(text_lower, ["quota", "license", "permit", "restriction"]) ->
        "Admissibility"

      String.contains?(text_lower, ["accounting", "reconciliation", "record"]) ->
        "Accounting"

      String.contains?(text_lower, ["transportation", "manifest", "arrival"]) ->
        "Transportation"

      String.contains?(text_lower, ["warehouse", "zone", "ftz"]) ->
        "Warehouse"

      true ->
        "General"
    end
  end

  defp determine_difficulty(question_text) do
    # Simple difficulty heuristic based on text complexity
    word_count = String.split(question_text) |> length()

    cond do
      word_count < 20 -> :easy
      word_count < 50 -> :medium
      true -> :hard
    end
  end

  defp evaluate_all_models(harness, questions) do
    Logger.info(
      "Evaluating #{length(questions)} questions across #{length(harness.models)} models"
    )

    results =
      if harness.evaluation_config.parallel_evaluation do
        evaluate_models_parallel(harness, questions)
      else
        evaluate_models_sequential(harness, questions)
      end

    {:ok, results}
  end

  defp evaluate_models_parallel(harness, questions) do
    # Group questions into batches for parallel processing
    batch_size = 10
    question_batches = Enum.chunk_every(questions, batch_size)

    Enum.flat_map(question_batches, fn batch ->
      batch_tasks =
        Enum.flat_map(batch, fn question ->
          Enum.map(harness.models, fn model ->
            Task.async(fn ->
              evaluate_question_with_model(harness, question, model)
            end)
          end)
        end)

      Task.await_many(batch_tasks, 60_000)
    end)
  end

  defp evaluate_models_sequential(harness, questions) do
    Enum.flat_map(questions, fn question ->
      Enum.map(harness.models, fn model ->
        evaluate_question_with_model(harness, question, model)
      end)
    end)
  end

  defp evaluate_question_with_model(harness, question, model) do
    start_time = System.monotonic_time(:millisecond)

    try do
      # Create DSPy agent for this model
      agent = create_cble_agent(model)

      # Prepare inputs with vision support if images present
      inputs = prepare_question_inputs(question)

      # Execute with retries
      case execute_with_retries(agent, inputs, harness.evaluation_config.max_retries) do
        {:ok, prediction} ->
          end_time = System.monotonic_time(:millisecond)
          execution_time = end_time - start_time

          response = extract_agent_response(prediction)

          %{
            model: model.name,
            model_id: model.model_id,
            question_id: question.question_id,
            question_text: question.question_text,
            correct_answer: question.correct_answer,
            agent_answer: response.answer,
            reasoning: response.reasoning,
            confidence: response.confidence,
            execution_time: execution_time,
            tokens_used: response.tokens_used,
            cost: calculate_cost(response.tokens_used, model.cost_per_token),
            success: true,
            error: nil,
            is_correct: response.answer == question.correct_answer,
            category: question.category,
            difficulty: question.difficulty,
            has_images: question.has_images,
            exam_date: question.exam_date
          }

        {:error, reason} ->
          end_time = System.monotonic_time(:millisecond)
          execution_time = end_time - start_time

          %{
            model: model.name,
            model_id: model.model_id,
            question_id: question.question_id,
            question_text: question.question_text,
            correct_answer: question.correct_answer,
            agent_answer: nil,
            reasoning: nil,
            confidence: 0.0,
            execution_time: execution_time,
            tokens_used: 0,
            cost: 0.0,
            success: false,
            error: inspect(reason),
            is_correct: false,
            category: question.category,
            difficulty: question.difficulty,
            has_images: question.has_images,
            exam_date: question.exam_date
          }
      end
    rescue
      exception ->
        Logger.error(
          "Exception evaluating question #{question.question_id} with #{model.name}: #{inspect(exception)}"
        )

        %{
          model: model.name,
          model_id: model.model_id,
          question_id: question.question_id,
          question_text: question.question_text,
          correct_answer: question.correct_answer,
          agent_answer: nil,
          reasoning: nil,
          confidence: 0.0,
          execution_time: 0,
          tokens_used: 0,
          cost: 0.0,
          success: false,
          error: "Exception: #{inspect(exception)}",
          is_correct: false,
          category: question.category,
          difficulty: question.difficulty,
          has_images: question.has_images,
          exam_date: question.exam_date
        }
    end
  end

  defp create_cble_agent(model) do
    # Create enhanced signature for CBLE questions
    signature =
      Dspy.EnhancedSignature.new("CBLEQuestion",
        description: "Solve Customs Broker License Examination questions with detailed reasoning",
        input_fields: [
          %{
            name: :question,
            type: :string,
            description: "CBLE question text",
            required: true,
            default: "",
            max_length: nil,
            vision_enabled: false,
            evaluation_weight: 1.0,
            display_priority: 1
          },
          %{
            name: :options,
            type: :string,
            description: "Multiple choice options",
            required: true,
            default: "",
            max_length: nil,
            vision_enabled: false,
            evaluation_weight: 1.0,
            display_priority: 2
          },
          %{
            name: :images,
            type: :image,
            description: "Associated diagrams or documents",
            required: false,
            vision_enabled: true,
            default: [],
            max_length: nil,
            evaluation_weight: 1.0,
            display_priority: 3
          },
          %{
            name: :context,
            type: :string,
            description: "Additional context or regulations",
            required: false,
            default: "",
            max_length: nil,
            vision_enabled: false,
            evaluation_weight: 0.5,
            display_priority: 4
          }
        ],
        output_fields: [
          %{
            name: :reasoning,
            type: :string,
            description: "Step-by-step reasoning process",
            required: true,
            default: "",
            max_length: nil,
            vision_enabled: false,
            evaluation_weight: 1.0,
            display_priority: 1
          },
          %{
            name: :answer,
            type: :string,
            description: "Selected answer (A, B, C, D, or E)",
            required: true,
            default: "",
            max_length: nil,
            vision_enabled: false,
            evaluation_weight: 1.0,
            display_priority: 2
          },
          %{
            name: :confidence,
            type: :number,
            description: "Confidence level (0.0-1.0)",
            required: true,
            default: 0.5,
            max_length: nil,
            vision_enabled: false,
            evaluation_weight: 0.5,
            display_priority: 3
          },
          %{
            name: :key_concepts,
            type: :string,
            description: "Key customs concepts applied",
            required: true,
            default: "",
            max_length: nil,
            vision_enabled: false,
            evaluation_weight: 0.5,
            display_priority: 4
          }
        ],
        vision_enabled: true,
        max_content_length: 20_000,
        evaluation_criteria: %{
          correctness_weight: 0.6,
          reasoning_weight: 0.25,
          confidence_weight: 0.15,
          completeness_weight: 0.0,
          efficiency_weight: 0.0,
          novelty_weight: 0.0
        },
        instructions: """
        You are an expert customs broker taking the CBLE examination. Analyze each question carefully,
        apply relevant customs regulations and procedures, and provide detailed reasoning for your answer.

        Consider:
        - Current customs regulations and tariff schedules
        - Trade agreement provisions (NAFTA, WTO, etc.)
        - Classification principles and methodologies
        - Valuation rules and methods
        - Entry procedures and documentation requirements
        - Admissibility and restrictions

        If images are provided, examine them carefully for relevant information such as:
        - Commercial invoices and documentation
        - Tariff schedule entries
        - Product specifications
        - Country of origin markings

        Select the best answer from the given options and provide your confidence level.
        """
      )

    # Configure language model for this specific model
    _lm =
      Dspy.LM.OpenAI.new(
        model: model.model_id,
        temperature: model.temperature,
        max_tokens: model.max_tokens
      )

    # Create sequential vision solver
    Dspy.SequentialVisionSolver.new(signature,
      vision_enabled: true,
      evaluation_config: %{
        enable_step_scoring: true,
        enable_reasoning_analysis: true,
        enable_vision_assessment: true
      }
    )
  end

  defp prepare_question_inputs(question) do
    options_text =
      if length(question.options) > 0 do
        Enum.join(question.options, "\n")
      else
        "Options not clearly identified in source material"
      end

    inputs = %{
      question: question.question_text,
      options: options_text,
      context: "CBLE Examination - Category: #{question.category}"
    }

    # Add images if present
    if question.has_images and length(question.images) > 0 do
      # Images should be passed as a list of structured vision content
      images =
        Enum.map(question.images, fn img ->
          %{
            type: :base64_image,
            content: img.data,
            processed: true
          }
        end)

      Map.put(inputs, :images, images)
    else
      inputs
    end
  end

  defp execute_with_retries(agent, inputs, max_retries) do
    Enum.reduce_while(0..max_retries, {:error, :max_retries_exceeded}, fn attempt, _acc ->
      case Dspy.Module.forward(agent, inputs) do
        {:ok, result} ->
          {:halt, {:ok, result}}

        {:error, reason} when attempt < max_retries ->
          Logger.warning("Attempt #{attempt + 1} failed: #{inspect(reason)}, retrying...")
          # Exponential backoff
          Process.sleep(1000 * (attempt + 1))
          {:cont, {:error, reason}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp extract_agent_response(prediction) do
    attrs = prediction.attrs

    # Handle both direct attributes and nested results
    result_data =
      if Map.has_key?(attrs, :final_outputs) do
        attrs.final_outputs
      else
        attrs
      end

    %{
      answer: extract_answer_letter(Map.get(result_data, :answer, "")),
      reasoning: Map.get(result_data, :reasoning, ""),
      confidence: parse_confidence(Map.get(result_data, :confidence, 0.5)),
      tokens_used: estimate_tokens_used(result_data)
    }
  end

  defp extract_answer_letter(answer_text) do
    # Extract letter from various answer formats
    case Regex.run(~r/\b([A-E])\b/i, to_string(answer_text)) do
      [_, letter] ->
        String.upcase(letter)

      nil ->
        # Fallback: try to find first letter
        case Regex.run(~r/^([A-E])/i, String.trim(to_string(answer_text))) do
          [_, letter] -> String.upcase(letter)
          nil -> "UNKNOWN"
        end
    end
  end

  defp parse_confidence(confidence) when is_number(confidence) do
    min(1.0, max(0.0, confidence))
  end

  defp parse_confidence(confidence) when is_binary(confidence) do
    case Float.parse(confidence) do
      {value, _} -> min(1.0, max(0.0, value))
      :error -> 0.5
    end
  end

  defp parse_confidence(_), do: 0.5

  defp estimate_tokens_used(result_data) do
    # Estimate tokens based on text length (rough approximation)
    text_content =
      [
        Map.get(result_data, :reasoning, ""),
        Map.get(result_data, :answer, ""),
        Map.get(result_data, :key_concepts, "")
      ]
      |> Enum.join(" ")
      |> String.length()

    # Rough estimate: 4 characters per token
    div(text_content, 4)
  end

  defp calculate_cost(tokens_used, cost_per_token) do
    tokens_used * cost_per_token
  end

  defp analyze_results(_harness, results) do
    Logger.info("Analyzing evaluation results")

    analysis = %{
      overall_performance: analyze_overall_performance(results),
      model_comparison: analyze_model_comparison(results),
      category_analysis: analyze_category_performance(results),
      difficulty_analysis: analyze_difficulty_performance(results),
      cost_analysis: analyze_cost_efficiency(results),
      vision_analysis: analyze_vision_performance(results),
      temporal_analysis: analyze_temporal_performance(results)
    }

    {:ok, analysis}
  end

  defp analyze_overall_performance(results) do
    successful_results = Enum.filter(results, & &1.success)

    %{
      total_questions: length(results),
      successful_evaluations: length(successful_results),
      success_rate: length(successful_results) / max(length(results), 1),
      overall_accuracy: calculate_overall_accuracy(successful_results),
      average_confidence: calculate_average_confidence(successful_results),
      total_cost: Enum.sum(Enum.map(results, & &1.cost)),
      average_execution_time: calculate_average_execution_time(results)
    }
  end

  defp analyze_model_comparison(results) do
    results
    |> Enum.group_by(& &1.model)
    |> Enum.map(fn {model, model_results} ->
      successful = Enum.filter(model_results, & &1.success)

      {model,
       %{
         questions_attempted: length(model_results),
         questions_successful: length(successful),
         success_rate: length(successful) / max(length(model_results), 1),
         accuracy: calculate_overall_accuracy(successful),
         average_confidence: calculate_average_confidence(successful),
         total_cost: Enum.sum(Enum.map(model_results, & &1.cost)),
         average_execution_time: calculate_average_execution_time(model_results),
         cost_per_correct_answer: calculate_cost_per_correct_answer(successful)
       }}
    end)
    |> Map.new()
  end

  defp analyze_category_performance(results) do
    results
    |> Enum.filter(& &1.success)
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {category, category_results} ->
      {category,
       %{
         questions_count: length(category_results),
         accuracy: calculate_overall_accuracy(category_results),
         average_confidence: calculate_average_confidence(category_results),
         models_performance: analyze_models_in_category(category_results)
       }}
    end)
    |> Map.new()
  end

  defp analyze_difficulty_performance(results) do
    results
    |> Enum.filter(& &1.success)
    |> Enum.group_by(& &1.difficulty)
    |> Enum.map(fn {difficulty, difficulty_results} ->
      {difficulty,
       %{
         questions_count: length(difficulty_results),
         accuracy: calculate_overall_accuracy(difficulty_results),
         average_confidence: calculate_average_confidence(difficulty_results),
         average_execution_time: calculate_average_execution_time(difficulty_results)
       }}
    end)
    |> Map.new()
  end

  defp analyze_cost_efficiency(results) do
    successful_results = Enum.filter(results, & &1.success)

    %{
      total_cost: Enum.sum(Enum.map(results, & &1.cost)),
      cost_per_question: calculate_cost_per_question(results),
      cost_per_correct_answer: calculate_cost_per_correct_answer(successful_results),
      most_cost_efficient_model: find_most_cost_efficient_model(results),
      cost_breakdown_by_model: calculate_cost_breakdown_by_model(results)
    }
  end

  defp analyze_vision_performance(results) do
    vision_results = Enum.filter(results, & &1.has_images)
    non_vision_results = Enum.filter(results, &(not &1.has_images))

    %{
      vision_questions_count: length(vision_results),
      non_vision_questions_count: length(non_vision_results),
      vision_accuracy: calculate_overall_accuracy(vision_results),
      non_vision_accuracy: calculate_overall_accuracy(non_vision_results),
      vision_vs_text_performance:
        compare_vision_vs_text_performance(vision_results, non_vision_results)
    }
  end

  defp analyze_temporal_performance(results) do
    results
    |> Enum.group_by(& &1.exam_date)
    |> Enum.map(fn {exam_date, exam_results} ->
      successful = Enum.filter(exam_results, & &1.success)

      {exam_date,
       %{
         questions_count: length(exam_results),
         accuracy: calculate_overall_accuracy(successful),
         average_execution_time: calculate_average_execution_time(exam_results),
         model_performance: analyze_models_in_exam(successful)
       }}
    end)
    |> Map.new()
  end

  defp generate_reports(harness, results, analysis) do
    Logger.info("Generating evaluation reports")

    with :ok <- save_raw_results(harness, results),
         :ok <- save_analysis_data(harness, analysis),
         :ok <- generate_summary_report(harness, results, analysis),
         :ok <- generate_detailed_report(harness, results, analysis),
         :ok <- generate_visualizations(harness, results, analysis) do
      {:ok, :reports_generated}
    else
      error -> error
    end
  end

  defp save_raw_results(harness, results) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    filename = "raw_results_#{timestamp}.json"
    filepath = Path.join([harness.output_path, "raw_results", filename])

    json_data = Jason.encode!(results, pretty: true)

    case File.write(filepath, json_data) do
      :ok -> :ok
      {:error, reason} -> {:error, {:save_failed, reason}}
    end
  end

  defp save_analysis_data(harness, analysis) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    filename = "analysis_#{timestamp}.json"
    filepath = Path.join([harness.output_path, "analysis", filename])

    json_data = Jason.encode!(analysis, pretty: true)

    case File.write(filepath, json_data) do
      :ok -> :ok
      {:error, reason} -> {:error, {:save_failed, reason}}
    end
  end

  defp generate_summary_report(harness, _results, analysis) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    filename = "summary_report_#{timestamp}.md"
    filepath = Path.join([harness.output_path, "reports", filename])

    report_content = """
    # CBLE Evaluation Summary Report

    Generated: #{timestamp}

    ## Overall Performance

    - **Total Questions Evaluated**: #{analysis.overall_performance.total_questions}
    - **Successful Evaluations**: #{analysis.overall_performance.successful_evaluations}
    - **Success Rate**: #{Float.round(analysis.overall_performance.success_rate * 100, 2)}%
    - **Overall Accuracy**: #{Float.round(analysis.overall_performance.overall_accuracy * 100, 2)}%
    - **Average Confidence**: #{Float.round(analysis.overall_performance.average_confidence, 3)}
    - **Total Cost**: $#{Float.round(analysis.overall_performance.total_cost, 4)}
    - **Average Execution Time**: #{Float.round(analysis.overall_performance.average_execution_time, 2)}ms

    ## Model Comparison

    #{generate_model_comparison_table(analysis.model_comparison)}

    ## Category Performance

    #{generate_category_performance_table(analysis.category_analysis)}

    ## Cost Analysis

    - **Total Cost**: $#{Float.round(analysis.cost_analysis.total_cost, 4)}
    - **Cost per Question**: $#{Float.round(analysis.cost_analysis.cost_per_question, 6)}
    - **Cost per Correct Answer**: $#{Float.round(analysis.cost_analysis.cost_per_correct_answer, 6)}
    - **Most Cost Efficient Model**: #{analysis.cost_analysis.most_cost_efficient_model}

    ## Vision vs Text Performance

    - **Vision Questions**: #{analysis.vision_analysis.vision_questions_count}
    - **Vision Accuracy**: #{Float.round(analysis.vision_analysis.vision_accuracy * 100, 2)}%
    - **Text-Only Questions**: #{analysis.vision_analysis.non_vision_questions_count}
    - **Text-Only Accuracy**: #{Float.round(analysis.vision_analysis.non_vision_accuracy * 100, 2)}%

    ## Recommendations

    #{generate_recommendations(analysis)}
    """

    case File.write(filepath, report_content) do
      :ok -> :ok
      {:error, reason} -> {:error, {:report_failed, reason}}
    end
  end

  defp generate_detailed_report(harness, results, _analysis) do
    # Generate detailed CSV report for further analysis
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    filename = "detailed_results_#{timestamp}.csv"
    filepath = Path.join([harness.output_path, "reports", filename])

    headers = [
      "model",
      "model_id",
      "question_id",
      "exam_date",
      "category",
      "difficulty",
      "has_images",
      "correct_answer",
      "agent_answer",
      "is_correct",
      "confidence",
      "execution_time",
      "tokens_used",
      "cost",
      "success",
      "error"
    ]

    csv_content = [Enum.join(headers, ",")]

    csv_rows =
      Enum.map(results, fn result ->
        [
          result.model,
          result.model_id,
          result.question_id,
          result.exam_date,
          result.category,
          result.difficulty,
          result.has_images,
          result.correct_answer || "",
          result.agent_answer || "",
          result.is_correct,
          result.confidence,
          result.execution_time,
          result.tokens_used,
          result.cost,
          result.success,
          result.error || ""
        ]
        |> Enum.map(&to_string/1)
        |> Enum.join(",")
      end)

    full_csv = Enum.join([csv_content | csv_rows], "\n")

    case File.write(filepath, full_csv) do
      :ok -> :ok
      {:error, reason} -> {:error, {:csv_failed, reason}}
    end
  end

  defp generate_visualizations(harness, results, analysis) do
    # Generate basic visualization data (could be enhanced with actual plotting)
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    filename = "visualization_data_#{timestamp}.json"
    filepath = Path.join([harness.output_path, "reports", filename])

    viz_data = %{
      model_accuracy_comparison: extract_model_accuracy_data(analysis.model_comparison),
      category_performance_breakdown: extract_category_data(analysis.category_analysis),
      cost_efficiency_comparison: extract_cost_efficiency_data(analysis.model_comparison),
      difficulty_performance: extract_difficulty_data(analysis.difficulty_analysis),
      execution_time_distribution: extract_timing_data(results)
    }

    json_data = Jason.encode!(viz_data, pretty: true)

    case File.write(filepath, json_data) do
      :ok -> :ok
      {:error, reason} -> {:error, {:viz_failed, reason}}
    end
  end

  # Helper functions for calculations and analysis

  defp calculate_overall_accuracy(results) do
    if length(results) > 0 do
      correct_count = Enum.count(results, & &1.is_correct)
      correct_count / length(results)
    else
      0.0
    end
  end

  defp calculate_average_confidence(results) do
    if length(results) > 0 do
      total_confidence = Enum.sum(Enum.map(results, & &1.confidence))
      total_confidence / length(results)
    else
      0.0
    end
  end

  defp calculate_average_execution_time(results) do
    if length(results) > 0 do
      total_time = Enum.sum(Enum.map(results, & &1.execution_time))
      total_time / length(results)
    else
      0.0
    end
  end

  defp calculate_cost_per_question(results) do
    if length(results) > 0 do
      total_cost = Enum.sum(Enum.map(results, & &1.cost))
      total_cost / length(results)
    else
      0.0
    end
  end

  defp calculate_cost_per_correct_answer(results) do
    correct_results = Enum.filter(results, & &1.is_correct)

    if length(correct_results) > 0 do
      total_cost = Enum.sum(Enum.map(correct_results, & &1.cost))
      total_cost / length(correct_results)
    else
      0.0
    end
  end

  defp find_most_cost_efficient_model(results) do
    grouped_results =
      results
      |> Enum.group_by(& &1.model)
      |> Enum.map(fn {model, model_results} ->
        correct_results = Enum.filter(model_results, & &1.is_correct)
        cost_per_correct = calculate_cost_per_correct_answer(correct_results)
        {model, cost_per_correct}
      end)

    case grouped_results do
      [] ->
        "N/A"

      models ->
        models
        |> Enum.min_by(fn {_, cost} -> cost end)
        |> elem(0)
    end
  end

  defp calculate_cost_breakdown_by_model(results) do
    results
    |> Enum.group_by(& &1.model)
    |> Enum.map(fn {model, model_results} ->
      total_cost = Enum.sum(Enum.map(model_results, & &1.cost))
      {model, total_cost}
    end)
    |> Map.new()
  end

  defp compare_vision_vs_text_performance(vision_results, non_vision_results) do
    %{
      vision_accuracy: calculate_overall_accuracy(vision_results),
      text_accuracy: calculate_overall_accuracy(non_vision_results),
      accuracy_difference:
        calculate_overall_accuracy(vision_results) -
          calculate_overall_accuracy(non_vision_results)
    }
  end

  defp analyze_models_in_category(category_results) do
    category_results
    |> Enum.group_by(& &1.model)
    |> Enum.map(fn {model, model_results} ->
      {model,
       %{
         accuracy: calculate_overall_accuracy(model_results),
         questions_count: length(model_results)
       }}
    end)
    |> Map.new()
  end

  defp analyze_models_in_exam(exam_results) do
    exam_results
    |> Enum.group_by(& &1.model)
    |> Enum.map(fn {model, model_results} ->
      {model,
       %{
         accuracy: calculate_overall_accuracy(model_results),
         questions_count: length(model_results)
       }}
    end)
    |> Map.new()
  end

  # Report generation helpers

  defp generate_model_comparison_table(model_comparison) do
    header =
      "| Model | Accuracy | Success Rate | Avg Confidence | Total Cost | Cost/Correct |\n|-------|----------|--------------|----------------|------------|--------------|"

    rows =
      Enum.map(model_comparison, fn {model, stats} ->
        "| #{model} | #{Float.round(stats.accuracy * 100, 1)}% | #{Float.round(stats.success_rate * 100, 1)}% | #{Float.round(stats.average_confidence, 3)} | $#{Float.round(stats.total_cost, 4)} | $#{Float.round(stats.cost_per_correct_answer, 6)} |"
      end)

    Enum.join([header | rows], "\n")
  end

  defp generate_category_performance_table(category_analysis) do
    header =
      "| Category | Questions | Accuracy | Avg Confidence |\n|----------|-----------|----------|----------------|"

    rows =
      Enum.map(category_analysis, fn {category, stats} ->
        "| #{category} | #{stats.questions_count} | #{Float.round(stats.accuracy * 100, 1)}% | #{Float.round(stats.average_confidence, 3)} |"
      end)

    Enum.join([header | rows], "\n")
  end

  defp generate_recommendations(analysis) do
    recommendations = []

    # Performance recommendations
    recommendations =
      if analysis.overall_performance.overall_accuracy < 0.7 do
        [
          "- Consider additional training on customs regulations and procedures",
          "- Review areas with lowest category performance for targeted improvement"
          | recommendations
        ]
      else
        recommendations
      end

    # Cost recommendations
    most_efficient = analysis.cost_analysis.most_cost_efficient_model

    recommendations = [
      "- **#{most_efficient}** provides the best cost efficiency for correct answers",
      "- Consider model selection based on question complexity and cost constraints"
      | recommendations
    ]

    # Vision recommendations
    vision_vs_text = analysis.vision_analysis.vision_vs_text_performance

    recommendations =
      if vision_vs_text.accuracy_difference < -0.1 do
        [
          "- Vision questions show significantly lower performance - consider vision-specific training",
          "- Review image analysis capabilities and document interpretation skills"
          | recommendations
        ]
      else
        recommendations
      end

    Enum.join(Enum.reverse(recommendations), "\n")
  end

  defp extract_model_accuracy_data(model_comparison) do
    Enum.map(model_comparison, fn {model, stats} ->
      %{model: model, accuracy: stats.accuracy}
    end)
  end

  defp extract_category_data(category_analysis) do
    Enum.map(category_analysis, fn {category, stats} ->
      %{category: category, accuracy: stats.accuracy, questions: stats.questions_count}
    end)
  end

  defp extract_cost_efficiency_data(model_comparison) do
    Enum.map(model_comparison, fn {model, stats} ->
      %{model: model, cost_per_correct: stats.cost_per_correct_answer}
    end)
  end

  defp extract_difficulty_data(difficulty_analysis) do
    Enum.map(difficulty_analysis, fn {difficulty, stats} ->
      %{difficulty: difficulty, accuracy: stats.accuracy, questions: stats.questions_count}
    end)
  end

  defp extract_timing_data(results) do
    results
    |> Enum.group_by(& &1.model)
    |> Enum.map(fn {model, model_results} ->
      times = Enum.map(model_results, & &1.execution_time)

      %{
        model: model,
        min_time: Enum.min(times),
        max_time: Enum.max(times),
        avg_time: Enum.sum(times) / length(times),
        median_time: Enum.at(Enum.sort(times), div(length(times), 2))
      }
    end)
  end
end
