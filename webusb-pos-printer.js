(function () {
    const KNOWN_DEVICES = [
        { vendorId: 0x0416, productId: 0x5011 },
        { vendorId: 0x0456, productId: 0x0808 },
        { vendorId: 0x0483, productId: 0x070b },
        { vendorId: 0x0519, productId: 0x2015 },
        { vendorId: 0x28e9, productId: 0x0289 },
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

        feedPaper(dots) {
            return this.append(`${ESC}J${u8(dots)}`);
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
            const mm = 8; // DPI = 203
            const encodedText = new PosEncoder()
                .reset()
                .setMode(1) // 8x16 font
                .setLeftMargin(4 * mm)
                .append(text)
                .feedPaper(15 * mm)
                .encode();

            const printer = await requestUsbPrinter();
            await printer.open();
            const endpoint = await connectEndpoint(printer, "out");
            await printer.transferOut(endpoint, encodedText);
        },
    };
})();
