#include "main.h"

int main(int argc, char **argv) {
    bool debug_enabled = false;
    std::string zabbix_server, host = "";
    for(;;) {
        switch(getopt(argc, argv, "z:n:?hd")) {
            case 'd':
                debug_enabled = true;
                continue;
            case 'n':
                host = std::string(optarg);
                continue;

            case 'z':
                zabbix_server = std::string(optarg);
                continue;

            case '?':
            case 'h':
            default :
                fprintf(stderr, "Usage:\n");
                fprintf(stderr, "-n <host>: Specify IP or hostname of a Zabbix host\n");
                fprintf(stderr, "-z <host>: Specify IP or hostname of a Zabbix server instance\n");
                exit(0);

            case -1:
                break;
        } // end switch(getopt(argc, argv, "z:n:?hd"))
        break;
    } // end for(;;)

    // check if environment variable is set (for container usage)
    if ( std::getenv("VERBOSE") != NULL) {
        debug_enabled = true;
    }

    // open DIAMEX temperature sensor as HID device
    hid_device *handle = hid_open(0x16c0, 0x0480, nullptr);
    if (!handle) {
        fprintf(stderr, "No temperature sensor found!\n");
        exit(1);
    }
    
    // define base command
    std::string cmd_first_sensor = std::string("echo '- server_rack_temperature[temperature,");
    std::string cmd_second_sensor = std::string("echo '- server_rack_temperature[temperature,");

    unsigned char buf[65];
    bool first_sensor_read, second_sensor_read = false;
    for (;;) {
        int num = hid_read(handle, buf, 64);
        if (num < 0) {
            fprintf(stderr, "Could not read from device!\n");
            exit(2);
        }

        // we need to read 64 bytes
        if (num == 64) {
            short temp = *(short *)&buf[4]; //this is fine. just enjoy your tea

            // first sensor
            if (buf[1] == 1) {
                cmd_first_sensor += "top] " + std::to_string((float)temp/10.0f);
                cmd_first_sensor += std::string("' | zabbix_sender -i - -s " + host + " -z " + zabbix_server);

                if (debug_enabled) {
                    fprintf(stderr, "Read first sensor, which reported temperature %.1f\n", (float)temp/10.0f);
                    cmd_first_sensor += " -vv\n";
                } else {
                    cmd_first_sensor += " 2>&1 > /dev/null\n";
                }

                first_sensor_read = true;
            // second sensor
            } else {

                second_sensor_read = true;

                // build command
                cmd_second_sensor += "bottom] " + std::to_string((float)temp/10.0f);
                cmd_second_sensor += std::string("' | zabbix_sender -i - -s " + host + " -z " + zabbix_server);

                if (debug_enabled) {
                    fprintf(stderr, "Read second sensor, which reported temperature %.1f\n", (float)temp/10.0f);
                    cmd_second_sensor += " -vv\n";
                } else {
                    cmd_second_sensor += " 2>&1 > /dev/null\n";
                }
            } // end if (buf[1] == 1)
       } // end if (num == 64)
       
       // both sensors read
       if (first_sensor_read && second_sensor_read) {
           break;
       };

    } // end for (;;)

	if (debug_enabled) {
	    fprintf(stderr, "Sending following commands:\n");
	    fprintf(stderr, cmd_first_sensor.c_str());
	    fprintf(stderr, cmd_second_sensor.c_str());
	}

    // send values to Zabbix
    int status = 0;
    bool command_failed = false;

    // first sensor
    status = std::system(cmd_first_sensor.c_str());
    if (status > 0) {
	    fprintf(stderr, "ERROR: Following command failed with return code '%i':\n", status);
	    fprintf(stderr, "%s\n", cmd_first_sensor.c_str());
        command_failed = true;
    }

    // second sensor
    status = std::system(cmd_second_sensor.c_str());
    if (status > 0) {
	    fprintf(stderr, "ERROR: Following command failed with return code '%i':\n", status);
	    fprintf(stderr, "%s\n", cmd_second_sensor.c_str());
        command_failed = true;
    }

    // make sure we exit accordingly if any command failed
    if (command_failed) {
        exit(3);
    } else {
        exit(0);
    }
}
// EOF
