# frozen_string_literal: true

require 'rails_helper'

describe Api::EpicOnFhir::Appointments do
  subject { described_class.call(patient_id) }

  let(:patient_id) { 'example_patient_id' }

  it 'when API return correct data' do
    stub_request(:post, ENV.fetch('EPIC_ON_FHIR_APPOINTMENTS_ENDPOINT').to_s)
      .with(query: { '_format' => 'json', 'patient' => patient_id })
      .to_return(status: 200, body: {
        resourceType: 'Bundle',
        type: 'searchset',
        total: 2,
        link: [
          {
            relation: 'self',
            url: 'https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4/Appointment?_format=json&patient=erXuFYUfucBZaryVksYEcMg3&identifier=1505'
          }
        ],
        entry: [
          {
            link: [
              {
                relation: 'self',
                url: 'https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4/Appointment/eO7YqdbPW-nhcgXdQIR0HUA3'
              }
            ],
            fullUrl: 'https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4/Appointment/eO7YqdbPW-nhcgXdQIR0HUA3',
            resource: {
              resourceType: 'Appointment',
              id: 'eO7YqdbPW-nhcgXdQIR0HUA3',
              identifier: [
                {
                  use: 'usual',
                  type: {
                    text: 'ORC'
                  },
                  system: 'urn:oid:1.2.840.114350.1.13.0.1.7.2.798267',
                  value: '1505'
                }
              ],
              status: 'booked',
              serviceCategory: [
                {
                  coding: [
                    {
                      system: 'http://open.epic.com/FHIR/StructureDefinition/appointment-service-category',
                      code: 'surgery',
                      display: 'Surgery'
                    }
                  ],
                  text: 'surgery'
                }
              ],
              specialty: [
                {
                  coding: [
                    {
                      system: 'urn:oid:1.2.840.114350.1.13.0.1.7.4.836982.5030',
                      code: '10',
                      display: 'Anesthesiology'
                    }
                  ],
                  text: 'Anesthesiology'
                }
              ],
              description: 'TRACHEOSTOMY [31601 (CPT®)] with Anesthesiologist Anesthesia, MD in EMH OR at  4:10 PM on 5/8/2023',
              start: '2023-05-09T05:10:00Z',
              end: '2023-05-09T06:30:00Z',
              minutesDuration: 80,
              created: '2023-05-08',
              participant: [
                {
                  type: [
                    {
                      coding: [
                        {
                          system: 'http://terminology.hl7.org/CodeSystem/v3-ParticipationType',
                          code: 'PART',
                          display: 'Participation'
                        }
                      ],
                      text: 'PART'
                    }
                  ],
                  actor: {
                    reference: 'Patient/erXuFYUfucBZaryVksYEcMg3',
                    display: 'Lopez, Camila Maria'
                  },
                  required: 'required',
                  status: 'accepted',
                  period: {
                    start: '2023-05-09T05:10:00Z',
                    end: '2023-05-09T06:30:00Z'
                  }
                },
                {
                  type: [
                    {
                      coding: [
                        {
                          system: 'http://terminology.hl7.org/CodeSystem/v3-ParticipationType',
                          code: 'PPRF',
                          display: 'primary performer'
                        }
                      ],
                      text: 'PPRF'
                    }
                  ],
                  actor: {
                    reference: 'Practitioner/enHmcmrIOygs4mq-t6soebQ3',
                    display: 'Anesthesiologist Anesthesia, MD'
                  },
                  required: 'required',
                  status: 'accepted',
                  period: {
                    start: '2023-05-09T05:25:00Z',
                    end: '2023-05-09T06:15:00Z'
                  }
                },
                {
                  type: [
                    {
                      coding: [
                        {
                          system: 'http://terminology.hl7.org/CodeSystem/v3-ParticipationType',
                          code: 'PART',
                          display: 'Participation'
                        }
                      ],
                      text: 'PART'
                    }
                  ],
                  actor: {
                    reference: 'Location/efR3SIdpRKF9BFBM5qakt9F5X1mWxjiAGu2hNTKbqOdI3',
                    display: 'Emh Or'
                  },
                  required: 'required',
                  status: 'accepted',
                  period: {
                    start: '2023-05-09T05:10:00Z',
                    end: '2023-05-09T06:30:00Z'
                  }
                },
                {
                  type: [
                    {
                      coding: [
                        {
                          system: 'http://terminology.hl7.org/CodeSystem/v3-ParticipationType',
                          code: 'PART',
                          display: 'Participation'
                        }
                      ],
                      text: 'PART'
                    }
                  ],
                  actor: {
                    reference: 'Location/e8BuMgFEFwXOmuu4ys1t8DWqnRI-CQIes8aWpqiK9khQ3',
                    display: 'EMH OR 9'
                  },
                  required: 'required',
                  status: 'accepted',
                  period: {
                    start: '2023-05-09T05:10:00Z',
                    end: '2023-05-09T06:30:00Z'
                  }
                }
              ],
              requestedPeriod: [
                {
                  start: '2023-05-08',
                  end: '2023-05-08'
                }
              ]
            },
            search: {
              mode: 'match'
            }
          },
          {
            link: [
              {
                relation: 'self',
                url: 'https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4/Appointment/el.K2In-0O4h6bYePmB.d6g3'
              }
            ],
            fullUrl: 'https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4/Appointment/el.K2In-0O4h6bYePmB.d6g3',
            resource: {
              resourceType: 'Appointment',
              id: 'el.K2In-0O4h6bYePmB.d6g3',
              identifier: [
                {
                  use: 'usual',
                  type: {
                    text: 'ORC'
                  },
                  system: 'urn:oid:1.2.840.114350.1.13.0.1.7.2.798267',
                  value: '1508'
                }
              ],
              status: 'fulfilled',
              serviceCategory: [
                {
                  coding: [
                    {
                      system: 'http://open.epic.com/FHIR/StructureDefinition/appointment-service-category',
                      code: 'surgery',
                      display: 'Surgery'
                    }
                  ],
                  text: 'surgery'
                }
              ],
              specialty: [
                {
                  coding: [
                    {
                      system: 'urn:oid:1.2.840.114350.1.13.0.1.7.4.836982.5030',
                      code: '110',
                      display: 'General'
                    }
                  ],
                  text: 'General'
                }
              ],
              description: 'APPENDECTOMY [44950 (CPT®)] with Physician Surgery, MD in EMH OR at 11:50 AM on 5/9/2023',
              start: '2023-05-09T14:51:00Z',
              end: '2023-05-09T15:25:00Z',
              minutesDuration: 75,
              created: '2023-05-09',
              patientInstruction: "Here are some basic reminders about your Appendectomy with Dr.\r\nSurgery\r\n1. Be sure to not eat after midnight the night before your surgery. Doing\r\nso may require that we delay your procedure. If you have questions, be\r\nsure to call the nurse at Dr. Surgery's office at (555)555-5555.\r\n2. Bring all of the medications that you are currently taking or that you\r\nhave recently taken. Dr. Surgery will make sure that you are prescribed\r\nthe appropriate medications after your surgery.\r\n3. It's important to arrange transportation to and from the\r\nhospital/clinic. You will not be in a position to drive yourself after the\r\nsurgery. The nurse will ask for your travel arrangements when you arrive.\r\n4. Please don't bring any unnecessary valuables with you. Jewelry, MP3\r\nplayers, watches, cell phones should all be left home if appropriate.\r\n\r\nIf you are unable to make your surgery date, please call Dr. Surgery's\r\nnurse (555-555-5555) as soon as possible.\r\n",
              participant: [
                {
                  type: [
                    {
                      coding: [
                        {
                          system: 'http://terminology.hl7.org/CodeSystem/v3-ParticipationType',
                          code: 'PART',
                          display: 'Participation'
                        }
                      ],
                      text: 'PART'
                    }
                  ],
                  actor: {
                    reference: 'Patient/erXuFYUfucBZaryVksYEcMg3',
                    display: 'Lopez, Camila Maria'
                  },
                  required: 'required',
                  status: 'accepted',
                  period: {
                    start: '2023-05-09T14:51:00Z',
                    end: '2023-05-09T15:25:00Z'
                  }
                },
                {
                  type: [
                    {
                      coding: [
                        {
                          system: 'http://terminology.hl7.org/CodeSystem/v3-ParticipationType',
                          code: 'PPRF',
                          display: 'primary performer'
                        }
                      ],
                      text: 'PPRF'
                    }
                  ],
                  actor: {
                    reference: 'Practitioner/eOyFJ.PiGBcbhr3T1oyJZ1A3',
                    display: 'Physician Surgery, MD'
                  },
                  required: 'required',
                  status: 'accepted',
                  period: {
                    start: '2023-05-09T15:06:00Z',
                    end: '2023-05-09T15:10:00Z'
                  }
                },
                {
                  type: [
                    {
                      coding: [
                        {
                          system: 'http://terminology.hl7.org/CodeSystem/v3-ParticipationType',
                          code: 'PART',
                          display: 'Participation'
                        }
                      ],
                      text: 'PART'
                    }
                  ],
                  actor: {
                    reference: 'Location/efR3SIdpRKF9BFBM5qakt9F5X1mWxjiAGu2hNTKbqOdI3',
                    display: 'Emh Or'
                  },
                  required: 'required',
                  status: 'accepted',
                  period: {
                    start: '2023-05-09T14:51:00Z',
                    end: '2023-05-09T15:25:00Z'
                  }
                },
                {
                  type: [
                    {
                      coding: [
                        {
                          system: 'http://terminology.hl7.org/CodeSystem/v3-ParticipationType',
                          code: 'PART',
                          display: 'Participation'
                        }
                      ],
                      text: 'PART'
                    }
                  ],
                  actor: {
                    reference: 'Location/eVdj5g6X2tilO0KIjBoqxuFcAal5uZv0JC50pxjzH4ow3',
                    display: 'EMH OR 13'
                  },
                  required: 'required',
                  status: 'accepted',
                  period: {
                    start: '2023-05-09T14:51:00Z',
                    end: '2023-05-09T15:25:00Z'
                  }
                }
              ],
              requestedPeriod: [
                {
                  start: '2023-05-09',
                  end: '2023-05-09'
                }
              ]
            },
            search: {
              mode: 'match'
            }
          }
        ]
      }.to_json)

    expect(subject.class).to be(Hash)
  end

  it 'when third party tool return empty collection' do
    stub_request(:post, ENV.fetch('EPIC_ON_FHIR_APPOINTMENTS_ENDPOINT').to_s)
      .with(query: { '_format' => 'json', 'patient' => patient_id })
      .to_return(status: 200, body: {
        resourceType: 'Bundle',
        type: 'searchset',
        total: 0,
        link: [
          {
            relation: 'self',
            url: 'https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4/Appointment?_format=json&patient=erXuFYUfucBZaryVksYEcMg3&identifier=1505'
          }
        ],
        entry: []
      }.to_json)

    expect { subject }.to raise_error(EpicOnFhir::NotFound)
  end
end
