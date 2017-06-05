/*
 * Package : mqtt_client
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 31/05/2017
 * Copyright :  S.Hamblett
 */
import 'package:mqtt_client/mqtt_client.dart';
import 'package:test/test.dart';
import 'package:typed_data/typed_data.dart' as typed;
import 'dart:io';

void main() {
  group("Header", () {
    /// Test helper method to call Get Remaining Bytes with a specific value
    typed.Uint8Buffer callGetRemainingBytesWithValue(int value) {
      // validates a payload size of a single byte using the example values supplied in the MQTT spec
      final MqttHeader header = new MqttHeader();
      header.messageSize = value;
      return header.getRemainingLengthBytes();
    }

    /// Creates byte array header with a single byte length
    /// byte1 - the first header byte
    /// length - the length byte
    typed.Uint8Buffer getHeaderBytes(int byte1, int length) {
      final typed.Uint8Buffer tmp = new typed.Uint8Buffer(2);
      tmp[0] = byte1;
      tmp[1] = length;
      return tmp;
    }

    /// Gets the MQTT header from a byte arrayed header.
    MqttHeader getMqttHeader(typed.Uint8Buffer headerBytes) {
      final ByteBuffer buff = new ByteBuffer(headerBytes);
      return new MqttHeader.fromByteBuffer(buff);
    }

    test("Single byte payload size", () {
      // Validates a payload size of a single byte using the example values supplied in the MQTT spec
      final returnedBytes = callGetRemainingBytesWithValue(127);
      // Check that the count of bytes returned is only 1, and the value of the byte is correct.
      expect(returnedBytes.length, 1);
      expect(returnedBytes[0], 127);
    });
    test("Double byte payload size lower boundary 128", () {
      final returnedBytes = callGetRemainingBytesWithValue(128);
      expect(returnedBytes.length, 2);
      expect(returnedBytes[0], 0x80);
      expect(returnedBytes[1], 0x01);
    });
    test("Double byte payload size upper boundary 16383", () {
      final returnedBytes = callGetRemainingBytesWithValue(16383);
      expect(returnedBytes.length, 2);
      expect(returnedBytes[0], 0xFF);
      expect(returnedBytes[1], 0x7F);
    });
    test("Triple byte payload size lower boundary 16384", () {
      final returnedBytes = callGetRemainingBytesWithValue(16384);
      expect(returnedBytes.length, 3);
      expect(returnedBytes[0], 0x80);
      expect(returnedBytes[1], 0x80);
      expect(returnedBytes[2], 0x01);
    });
    test("Triple byte payload size upper boundary 2097151", () {
      final returnedBytes = callGetRemainingBytesWithValue(2097151);
      expect(returnedBytes.length, 3);
      expect(returnedBytes[0], 0xFF);
      expect(returnedBytes[1], 0xFF);
      expect(returnedBytes[2], 0x7F);
    });
    test("Quadruple byte payload size lower boundary 2097152", () {
      final returnedBytes = callGetRemainingBytesWithValue(2097152);
      expect(returnedBytes.length, 4);
      expect(returnedBytes[0], 0x80);
      expect(returnedBytes[1], 0x80);
      expect(returnedBytes[2], 0x80);
      expect(returnedBytes[3], 0x01);
    });
    test("Quadruple byte payload size upper boundary 268435455", () {
      final returnedBytes = callGetRemainingBytesWithValue(268435455);
      expect(returnedBytes.length, 4);
      expect(returnedBytes[0], 0xFF);
      expect(returnedBytes[1], 0xFF);
      expect(returnedBytes[2], 0xFF);
      expect(returnedBytes[3], 0x7F);
    });
    test("Payload size out of upper range", () {
      final MqttHeader header = new MqttHeader();
      bool raised = false;
      header.messageSize = 2;
      try {
        header.messageSize = 268435456;
      } catch (InvalidPayloadSizeException) {
        raised = true;
      }
      expect(raised, isTrue);
      expect(header.messageSize, 2);
    });
    test("Payload size out of lower range", () {
      final MqttHeader header = new MqttHeader();
      bool raised = false;
      header.messageSize = 2;
      try {
        header.messageSize = -1;
      } catch (InvalidPayloadSizeException) {
        raised = true;
      }
      expect(raised, isTrue);
      expect(header.messageSize, 2);
    });
    test("Duplicate", () {
      final MqttHeader header = new MqttHeader().isDuplicate();
      expect(header.duplicate, isTrue);
    });
    test("Qos", () {
      final MqttHeader header = new MqttHeader().withQos(MqttQos.atMostOnce);
      expect(header.qos, MqttQos.atMostOnce);
    });
    test("Message type", () {
      final MqttHeader header =
      new MqttHeader().asType(MqttMessageType.publishComplete);
      expect(header.messageType, MqttMessageType.publishComplete);
    });
    test("Retain", () {
      final MqttHeader header = new MqttHeader().shouldBeRetained();
      expect(header.retain, isTrue);
    });
    test("Round trip", () {
      final MqttHeader inputHeader = new MqttHeader();
      inputHeader.duplicate = true;
      inputHeader.retain = false;
      inputHeader.messageSize = 1;
      inputHeader.messageType = MqttMessageType.connect;
      inputHeader.qos = MqttQos.atLeastOnce;
      final ByteBuffer buffer = new ByteBuffer(new typed.Uint8Buffer());
      inputHeader.writeTo(1, buffer);
      final MqttHeader outputHeader = new MqttHeader.fromByteBuffer(buffer);
      expect(inputHeader.duplicate, outputHeader.duplicate);
      expect(inputHeader.retain, outputHeader.retain);
      expect(inputHeader.messageSize, outputHeader.messageSize);
      expect(inputHeader.messageType, outputHeader.messageType);
      expect(inputHeader.qos, outputHeader.qos);
    });
    test("Corrupt header", () {
      final MqttHeader inputHeader = new MqttHeader();
      inputHeader.duplicate = true;
      inputHeader.retain = false;
      inputHeader.messageSize = 268435455;
      inputHeader.messageType = MqttMessageType.connect;
      inputHeader.qos = MqttQos.atLeastOnce;
      final ByteBuffer buffer = new ByteBuffer(new typed.Uint8Buffer());
      inputHeader.writeTo(268435455, buffer);
      // Fudge the header by making the last bit of the 4th message size byte a 1, therefore making the header
      // invalid because the last bit of the 4th size byte should always be 0 (according to the spec). It's how
      // we know to stop processing the header when reading a full message).
      buffer.readByte();
      buffer.readByte();
      buffer.readByte();
      buffer.writeByte(buffer.readByte() | 0xFF);
      bool raised = false;
      try {
        final MqttHeader outputHeader = new MqttHeader.fromByteBuffer(buffer);
      } catch (InvalidHeaderException) {
        raised = true;
      }
      expect(raised, true);
    });
    test("Corrupt header undersize", () {
      final ByteBuffer buffer = new ByteBuffer(new typed.Uint8Buffer());
      buffer.writeByte(0);
      bool raised = false;
      try {
        final MqttHeader outputHeader = new MqttHeader.fromByteBuffer(buffer);
      } catch (InvalidHeaderException) {
        raised = true;
      }
      expect(raised, true);
    });
    test("QOS at most once", () {
      final typed.Uint8Buffer headerBytes = getHeaderBytes(1, 0);
      final MqttHeader header = getMqttHeader(headerBytes);
      expect(header.qos, MqttQos.atMostOnce);
    });
    test("QOS at least once", () {
      final typed.Uint8Buffer headerBytes = getHeaderBytes(2, 0);
      final MqttHeader header = getMqttHeader(headerBytes);
      expect(header.qos, MqttQos.atLeastOnce);
    });
    test("QOS exactly once", () {
      final typed.Uint8Buffer headerBytes = getHeaderBytes(4, 0);
      final MqttHeader header = getMqttHeader(headerBytes);
      expect(header.qos, MqttQos.exactlyOnce);
    });
    test("QOS reserved1", () {
      final typed.Uint8Buffer headerBytes = getHeaderBytes(6, 0);
      final MqttHeader header = getMqttHeader(headerBytes);
      expect(header.qos, MqttQos.reserved1);
    });
  });
}