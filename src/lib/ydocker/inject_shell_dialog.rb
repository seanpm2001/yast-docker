# Copyright (c) 2014 SUSE LLC.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
# Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact Novell about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

require "yast"
require "yast2/execute"
require "shellwords"

module YDocker
  class InjectShellDialog
    include Yast::UIShortcuts
    include Yast::I18n
    extend Yast::I18n

    def initialize(container)
      textdomain "docker"
      @container = container
    end

    def run
      return unless create_dialog

      begin
        controller_loop
      ensure
        close_dialog
      end
    end

    def create_dialog
      Yast::UI.OpenDialog dialog_content
    end

    def close_dialog
      Yast::UI.CloseDialog
    end

    def controller_loop
      # no need to loop, one shot is enough
      input = Yast::UI.UserInput
      case input
      when :ok
        attach
      when :cancel
        nil
      else
        raise "Unknown action #{input}"
      end
    end

    def dialog_content
      VBox(
        headings,
        contents,
        ending_buttons
      )
    end

    def headings
      Heading(_("Inject Shell"))
    end

    def contents
      VBox(
        ComboBox(
          Id(:shell),
          Opt(:editable, :hstretch),
          _("Target Shell"),
          proposed_shells
        )
      )
    end

    def ending_buttons
      HBox(
        PushButton(Id(:ok), _("&Ok")),
        PushButton(Id(:cancel), _("&Cancel"))
      )
    end

    SHELLS = ["bash", "sh", "zsh", "csh"].freeze
    def proposed_shells
      SHELLS.map { |shell| Item(Id(shell), shell) }
    end

    def attach
      selected_shell = Yast::UI.QueryWidget(:shell, :Value)

      docker_command = "docker exec -ti #{@container.id} %{shell}"

      if Yast::UI.TextMode
        command = format(docker_command, shell: Shellwords.escape(selected_shell))

        Yast::UI.RunInTerminal(command + " 2>&1")
      else
        begin
          # Note that the selected shell is not escaped here. The whole command will
          # be escaped by Yast::Execute
          command = format(docker_command, shell: selected_shell) +
            " || (echo \"Failed to attach. Will close window in 5 seconds\";sleep 5)"

          Yast::Execute.locally!("xterm", "-e", command)
        rescue Cheetah::ExecutionFailed => e
          Yast::Popup.Error(
            format(_("Failed to run terminal. Error: %{error}"), error: e.message)
          )
        end
      end
    end
  end
end
