local InputDialog = require("ui/widget/inputdialog")
local ChatGPTViewer = require("chatgptviewer")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local _ = require("gettext")

local queryChatGPT = require("gpt_query")

local function showLoadingDialog()
  local loading = InfoMessage:new{
    text = _("Loading..."),
    timeout = 0.1
  }
  UIManager:show(loading)
end

local function showChatGPTDialog(ui, highlightedText, message_history)
  local title, author = 
    ui.document:getProps().title or _("Unknown Title"),
    ui.document:getProps().authors or _("Unknown Author")
  local message_history = message_history or {{
    role = "system",
    content = [[The following is a conversation with an AI assistant. 
    The assistant is helpful, creative, clever, and very friendly. 
    In case the user writes a question, answer it concisely. You also listen to these shortcuts:
    s - summarize the text
    t - translate the text to German
    
    For the summarization features, follow these rules:
    
    Take a deep breath and think step by step about how to best accomplish this goal using the following steps.

    # OUTPUT SECTIONS

    - Combine all of your understanding of the content into a single, 20-word sentence in a section called ONE SENTENCE SUMMARY:.

    - Output the 10 most important points of the content as a list with no more than 15 words per point into a section called MAIN POINTS:.

    - Output a list of the 5 best takeaways from the content in a section called TAKEAWAYS:.

    # OUTPUT INSTRUCTIONS

    - Create the output using the formatting above.
    - You only output human readable Markdown.
    - Output numbered lists, not bullets.
    - Do not output warnings or notes—just the requested sections.
    - Do not repeat items in the output sections.
    - Do not start items with the same opening words.
]]
    }}
  local input_dialog
  input_dialog = InputDialog:new{
    title = _("Ask a question about the highlighted text"),
    input_hint = _("Type your question here..."),
    input_type = "text",
    buttons = {{{
      text = _("Cancel"),
      callback = function()
        UIManager:close(input_dialog)
      end
    }, {
      text = _("Ask"),
      callback = function()
        local question = input_dialog:getInputText()
        UIManager:close(input_dialog)
        showLoadingDialog()

        -- do the actual work after a short delay to allow the loading dialog to show
        UIManager:scheduleIn(0.1, function()
          -- Give context to the question
          local context_message = {
            role = "user",
            content = "I'm reading something titled '" .. title .. "' by " .. author ..
              ". I have a question about the following highlighted text: " .. highlightedText
          }
          table.insert(message_history, context_message)

          -- Ask the question
          local question_message = {
            role = "user",
            content = question
          }
          table.insert(message_history, question_message)

          local answer = queryChatGPT(message_history)
          -- Save the answer to the message history
          local answer_message = {
            role = "assistant",
            content = answer
          }

          table.insert(message_history, answer_message)
          local result_text = _("User: ") ..
                                question .. "\n\n" .. _("ChatGPT: ") .. answer

          local function createResultText(highlightedText, message_history)
--[[             local result_text = _("Highlighted text: ") .. "\"" .. highlightedText .. "\"\n\n" ]]
            local result_text = ""
            for i = 3, #message_history do
              if message_history[i].role == "user" then
                result_text = result_text .. _("User: ") .. message_history[i].content .. "\n\n"
              else
                result_text = result_text .. _("ChatGPT: ") .. message_history[i].content .. "\n\n"
              end
            end

            return result_text
          end

          local function handleNewQuestion(chatgpt_viewer, question)
            -- Add the new question to the message history
            table.insert(message_history, {
              role = "user",
              content = question
            })

            -- Send the query to ChatGPT with the updated message_history
            local answer = queryChatGPT(message_history)

            -- Add the answer to the message history
            table.insert(message_history, {
              role = "assistant",
              content = answer
            })

            -- Update the result text
            local result_text = createResultText(highlightedText, message_history)

            -- Update the text and refresh the viewer
            chatgpt_viewer:update(result_text)
          end

          local chatgpt_viewer = ChatGPTViewer:new {
            title = _("AskGPT"),
            text = result_text,
            onAskQuestion = handleNewQuestion -- Pass the callback function
          }

          UIManager:show(chatgpt_viewer)
        end)
      end
    }}}
  }
  UIManager:show(input_dialog)
  input_dialog:onShowKeyboard()
end

return showChatGPTDialog
