(function () {
    const KNOWN_DEVICES = [
        { vendorId: 0x0416, productId: 0x5011, model: "POS-58" },
        { vendorId: 0x0456, productId: 0x0808, model: "POS-58" },
        { vendorId: 0x0483, productId: 0x070b, model: "POS-58" },
        { vendorId: 0x0519, productId: 0x2015, model: "POS-58" },
        { vendorId: 0x28e9, productId: 0x0289, model: "POS-58" },
        { vendorId: 0x1fc9, productId: 0x2016, model: "POS-80" },
    ];

    const ESC = "\x1b";
    const GS = "\x1d";

    function u8(value) {
        return String.fromCharCode(value & 0xff);
    }

    function u16(value) {
        return `${u8(value)}${u8(value >> 8)}`;
    }

    class PosEncoder {
        constructor() {
            this.data = "";
        }

        encode() {
            return new TextEncoder().encode(this.data);
        }

        append(data) {
            this.data += data;
            return this;
        }

        reset() {
            return this.append(`${ESC}@`);
        }

        setMode(mode) {
            return this.append(`${ESC}!${u8(mode)}`);
        }

        setLeftMargin(dots) {
            return this.append(`${GS}L${u16(dots)}`);
        }

        feedPaper(lines) {
            return this.append(new Array(lines + 1).join("\n"));
        }

        cutPaper() {
            return this.append(`${GS}V${u8(1)}`);
        }
    }

    async function requestUsbPrinter() {
        for (const device of await navigator.usb.getDevices()) {
            for (const knownDevice of KNOWN_DEVICES) {
                if (
                    knownDevice.vendorId === device.vendorId &&
                    knownDevice.productId === device.productId
                ) {
                    return device;
                }
            }
        }

        return navigator.usb.requestDevice({ filters: KNOWN_DEVICES });
    }

    function getPrinterModel(device) {
        for (const knownDevice of KNOWN_DEVICES) {
            if (
                device.vendorId === knownDevice.vendorId &&
                device.productId === device.productId
            ) {
                return knownDevice.model;
            }
        }
    }

    async function connectEndpoint(device, direction) {
        for (const config of device.configurations) {
            for (const iface of config.interfaces) {
                for (const alternate of iface.alternates) {
                    for (const endpoint of alternate.endpoints) {
                        if (endpoint.direction === direction) {
                            await device.selectConfiguration(
                                config.configurationValue,
                            );
                            if (!iface.claimed) {
                                await device.claimInterface(
                                    iface.interfaceNumber,
                                );
                            }
                            return endpoint.endpointNumber;
                        }
                    }
                }
            }
        }

        const deviceName = `${device.manufacturerName} ${device.productName}`;
        const message = `'${direction}' endpoint not found for '${deviceName}'`;
        throw new Error(message);
    }

    window.webusbPosPrinter = {
        async printText(text) {
            const printer = await requestUsbPrinter();
            const model = getPrinterModel(printer);

            const mm = 8; // DPI = 203

            const encoder = new PosEncoder();
            switch (model) {
                case "POS-58":
                    encoder
                        .reset()
                        .setMode(1) // 8x16 font
                        .setLeftMargin(4 * mm)
                        .append(text)
                        .feedPaper(8);
                    break;
                case "POS-80":
                    encoder
                        .reset()
                        .setMode(0) // 12x24 font
                        .setLeftMargin(7 * mm)
                        .append(text)
                        .feedPaper(10)
                        .cutPaper()
                        .feedPaper(3);
                    break;
            }
            const encodedText = encoder.encode();

            await printer.open();
            const endpoint = await connectEndpoint(printer, "out");
            await printer.transferOut(endpoint, encodedText);
        },
    };
})();
