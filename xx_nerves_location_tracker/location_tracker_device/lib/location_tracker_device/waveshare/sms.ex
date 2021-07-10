defmodule WaveshareHat.SMS do
  @moduledoc """
  Includes helper functions for sending and receiving SMS.
  """

  import WaveshareHat.Utils

  @doc """
  Set the number from which SMS message are sent.
  """
  def set_local_number(pid, number), do: write(pid, "AT+CSCA=\"#{number}\"")

  @doc """
  Set the format of SMS messages to Text (1) or PDU (0) mode.
  """
  def set_sms_mode(pid, mode) when mode in [0, 1] do
    write(pid, "AT+CMGF=#{mode}")
  end

  @doc """
  Set the TE character set to GSM or UCS2.
  """
  def set_te_character_set(pid, set) when set in ["GSM", "UCS2"] do
    write(pid, "AT+CSCS=#{set}")
  end

  @doc """
  Set the SMS text mode parameters.

  The parameters must be a list in the following order: `[fo, vp, pid, dcs]`.

  Every value but the `fo`-parameter are optional.

  Below is a list of possible parameters and their meaning.

  ## fo
  Depending on the command or result code:
  * first octet of GSM 03.40 SMS-DELIVER
  * SMS-SUBMIT (default `17`)
  * SMS-STATUS-REPORT
  * SMS-COMMAND (default `2`) in integer format.

  > SMS status report is supported under text mode if `<fo>` is set to `49`.

  ## vp
  Depending on SMS-SUBMIT `<fo>` setting:
  GSM 03.40 TP-Validity-Period either in
  * integer format (default `167`) or
  * in time-string format (refer `<dt>`)

  ## pid
  GSM 03.40 TP-Protocol-Identifier in integer format (default `0`).

  ## dcs
  GSM 03.38 SMS Data Coding Scheme in Integer format.
  """
  def set_sms_mode_params(pid, params) when is_list(params) do
    write(pid, "AT+CSMP=#{Enum.join(params, ",")}")
  end

  def set_sms_mode_params(pid, param) when is_integer(param) do
    set_sms_mode_params(pid, [param])
  end

  @doc """
  Set the SMS message text body.
  Can be used multiple times for multiple lines.

  Don't forget to finish the text input with an `end_mark/1`.
  """
  def set_sms_body(pid, body) when is_binary(body) do
    write(pid, "> #{body}")
  end

  @doc """
  Reads a SMS message at a given position of the inbox.
  """
  def read_sms(pid, position), do: write(pid, "AT+CMGR=#{position}")

  @doc """
  Sends a previously entered message to a given number.

  This is the last command necessary for sending a SMS.
  Make sure to write a message before like this:

      iex> WaveshareHat.set_local_number(pid, "YOUR_NUMBER")
      iex> WaveshareHat.set_sms_body(pid, "Hello there, friend!")
      iex> WaveshareHat.end_mark(pid)
      iex> WaveshareHat.send_sms(pid, "YOUR_FRIENDS_NUMBER")

  """
  def send_sms(pid, to_number), do: write(pid, "AT+CMGS=\"#{to_number}\"")

  # Configuration
  @doc """
  Set the ATE echo mode On (1) or Off (0).
  """
  def set_echo_mode(pid, mode) when mode in [0, 1] do
    write(pid, "ATE#{mode}")
  end

  @doc """
  Enable (1) or disable (0) COLP notifications.
  """
  def set_colp_notification(pid, status) when status in [0, 1] do
    write(pid, "AT+COLP=#{status}")
  end

  @doc """
  Set the SMS text mode parameters.

  The parameters must be a list in the following order: `[mode, mt, bm, ds, bfr]`.
  Every value but the `mode`-parameter are optional.

  Below is a list of possible parameters and their meaning.

  ## Mode
    * `0` -  Buffer unsolicited result codes in the TA. If TA result
    code buffer is full, indications can be buffered in some other place or the
    oldest indications may be discarded and replaced with the new received
    indications.
    * `1` - Discard indication and reject new received message
    unsolicited result codes when TA-TE link is reserved (e.g. in on-line data
    mode). Otherwise forward them directly to the TE.
    * `2` - Buffer unsolicited result codes in the TA when TA-TE
    link is reserved (e.g. in on-line data mode) and flush them to the TE after
    reservation. Otherwise forward them directly to the TE.
    * `3` - Forward unsolicited result codes directly to the TE.
    TA-TE link specific inband technique used to embed result codes and data
    when TA is in on-line data mode.

  ## mt
    * `0` - No SMS-DELIVER indications are routed to the TE.
    * `1` - If SMS-DELIVER is stored into ME/TA, indication of the memory location
    is routed to the TE using unsolicited result code: `+CMTI: <mem>,<index>`
    * `2` - SMS-DELIVERs (except class 2) are routed directly to the TE using unsolicited result code:
    `+CMT: [<alpha>],<length><CR><LF><pdu>` (PDU mode enabled) or
    `+CMT: <oa>,[<alpha>],<scts> [,<tooa>,<fo>,<pid>,<dcs>,<sca>,<tosca>,<length>]<CR><LF><data>`
      Class 2 messages result in indication as defined in <mt>=1.
    * `3` - Class 3 SMS-DELIVERs are routed directly to TE using unsolicited result codes defined in `<mt>=2`.
    Messages of other classes result in indication as defined in `<mt>=1`.

  ## bm
  > The rules for storing received CBMs depend on its data coding scheme (refer GSM 03.38 [2]), the setting of Select CBM Types (+CSCB) and this value:
  * `0` - No CBM indications are routed to the TE.
  * `2` - New CBMs are routed directly to the TE using unsolicited result code:
  `+CBM: <length><CR><LF><pdu>` (PDU mode enabled) or
  `+CBM: <sn>,<mid>,<dcs>,<page>,<pages><CR><LF><data>` (text mode enabled).

  ## ds
  * `0` - No SMS-STATUS-REPORTs are routed to the TE.
  * `1` - SMS-STATUS-REPORTs are routed to the TE using unsolicited result code:
  `+CDS:<length><CR><LF><pdu>` (PDU mode enabled) or
  `+CDS: <fo>,<mr>[,<ra>][,<tora>],<scts>,<dt>,<st>` (text mode enabled)

  ## bfr
  * `0` - TA buffer of unsolicited result codes defined within this Command is flushed to the TE when `<mode> 1...3` is entered (OK response shall be given before flushing the codes).
  * `1` - TA buffer of unsolicited result codes defined within this command is cleared when `<mode> 1...3` is entered
  """
  def set_new_sms_indicator(pid, modes) when is_list(modes) do
    write(pid, "AT+CNMI=#{Enum.join(modes, ",")}")
  end

  def set_new_sms_indicator(pid, mode) when is_integer(mode) do
    set_new_sms_indicator(pid, [mode])
  end
end
