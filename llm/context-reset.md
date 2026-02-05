Hello. I would like to create a new, focused context for our work. The goal is to distill our conversation into a clean "handoff prompt" that I can use to start a new chat. This new prompt should contain only the essential information needed for the next phase of our task, intentionally omitting conversational tangents, resolved debates, or exploratory ideas that are no longer relevant.

Your task is to act as a "Context Distiller." To do this, please follow this two-step process:

**Step 1: Analysis and Clarification**

1. Analyze our entire conversation up to this point.

2. Identify the core objective, the current status, and the key decisions we've made.

3. Identify any topics or constraints that are "ambiguous" in their importance for the *next* step. (For example: Was a concept mentioned during initial brainstorming, or is it a strict requirement for the final output? Is a past discussion about "why" we're doing something still relevant, or do we only need the final decision?)

4. **Before generating the final prompt,** ask me a set of clarifying questions about these ambiguous points. This will give me the opportunity to tell you what to include and what to discard. Please wait for my response.

**Step 2: Generate the Final Handoff Prompt**

1. After I have answered your clarifying questions, generate the single, comprehensive handoff prompt.

2. This prompt must be self-contained and structured with the following sections:

   * **Primary Goal:** A concise summary of the overall objective for the *next phase* of our work.

   * **Current Status:** A description of where we are in the process *right now*.

   * **Key Decisions, Data, and Constraints:** A bulleted list of only the *currently relevant* information, established facts, user preferences, and constraints that must be remembered.

   * **Immediate Next Step:** A clear statement of the very next task or question that needs to be addressed in the new chat.

   * **Required Persona & Tone:** A description of any specific persona, role (e.g., "expert programmer," "creative writer"), or conversational tone that should be used.

3. Please output *only* the generated prompt, formatted within a `text code block`, so I can easily copy and paste it. Do not add any conversational text before or after the final prompt itself.